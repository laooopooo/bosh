require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/configs_controller'

module Bosh::Director
  describe Api::Controllers::ConfigsController do
    include Rack::Test::Methods

    subject(:app) { Api::Controllers::ConfigsController.new(config) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'GET', '/' do
      context 'with authenticated admin user' do
        before(:each) do
          authorize('admin', 'admin')
        end

        it 'returns the list of configs' do
          Models::Config.make
          Models::Config.make
          Models::Config.make(name: 'new-name')
          Models::Config.make(type: 'new-type')

          get '/'

          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(3)
          expect(JSON.parse(last_response.body).first['name']).to eq('some-name')
        end

        it 'returns an empty list if nothing matches' do
          get '/'

          expect(last_response.status).to eq(200)
          result = JSON.parse(last_response.body)
          expect(result.class).to be(Array)
          expect(result).to eq([])
        end
      end

      context 'without an authenticated user' do
        it 'denies access' do
          expect(get('/').status).to eq(401)
        end
      end
    end

    describe 'GET', '/:type' do
      context 'with authenticated admin user' do
        before(:each) do
          authorize('admin', 'admin')
        end

        it 'returns the number of configs specified by ?limit' do
          Models::Config.make(
            content: 'some-yaml',
            created_at: Time.now - 3.days
          )

          Models::Config.make(
            content: 'some-other-yaml',
            created_at: Time.now - 2.days
          )

          newest_config = 'new_config'
          Models::Config.make(
            content: newest_config,
            created_at: Time.now - 1
          )

          get '/my-type?name=some-name&limit=2'

          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
        end

        context 'when name is missing from the params' do
          before do
            Models::Config.make(
                name: 'with-some-name',
                content: 'some_config'
            )

            Models::Config.make(
                name: '',
                content: 'config-with-empty-name'
            )
          end

          let(:url_path) { '/my-type?limit=10' }

          it 'uses the default name' do
            get url_path

            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq('config-with-empty-name')
          end
        end

        context 'when not all required parameters are provided' do
          context "when 'limit' is not specified" do
            let(:url_path) { '/my-type?name=some-name' }

            it 'returns STATUS 400' do
              get url_path

              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq('{"code":40001,"description":"\'limit\' is required"}')
            end
          end

          context "when 'limit' value is not given" do
            let(:url_path) { '/my-type?name=some-name&limit=' }

            it 'returns STATUS 400' do
              get url_path

              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq('{"code":40001,"description":"\'limit\' is required"}')
            end
          end

          context "when 'limit' value is not an integer" do
            let(:url_path) { '/my-type?name=some-name&limit=foo' }

            it 'returns STATUS 400' do
              get url_path

              expect(last_response.status).to eq(400)
              expect(last_response.body).to eq('{"code":40000,"description":"\'limit\' is invalid: \'foo\' is not an integer"}')
            end
          end
        end
      end

      context 'without an authenticated user' do
        it 'denies access' do
          expect(get('/my-type').status).to eq(401)
        end
      end

      context 'when user is reader' do
        before { basic_authorize('reader', 'reader') }

        it 'permits access' do
          expect(get('/my-type?limit=1').status).to eq(200)
        end
      end
    end

    describe 'POST', '/:type' do
      let(:content) { YAML.dump(Bosh::Spec::Deployments.simple_runtime_config) }

      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        it 'creates a new config' do
          expect {
            post '/my-type', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

          expect(last_response.status).to eq(201)
          expect(Bosh::Director::Models::Config.first.content).to eq(content)
        end

        it 'creates new config and does not update existing ' do
          post '/my-type', content, {'CONTENT_TYPE' => 'text/yaml'}
          expect(last_response.status).to eq(201)

          expect {
            post '/my-type', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Config, :count).from(1).to(2)

          expect(last_response.status).to eq(201)
          expect(Bosh::Director::Models::Config.last.content).to eq(content)
        end

        it 'gives a nice error when request body is not a valid yml' do
          post '/my-type', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['code']).to eq(440001)
          expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded manifest: ')
        end

        it 'gives a nice error when request body is empty' do
          post '/my-type', '', {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)).to eq(
              'code' => 440001,
              'description' => 'Manifest should not be empty',
          )
        end

        it 'creates a new event' do
          expect {
            post '/my-type', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq('config')
          expect(event.object_name).to eq('')
          expect(event.action).to eq('create')
          expect(event.user).to eq('admin')
        end

        it 'creates a new event with error' do
          expect {
            post '/my-type', {}, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq('config')
          expect(event.object_name).to eq('')
          expect(event.action).to eq('create')
          expect(event.user).to eq('admin')
          expect(event.error).to eq('Manifest should not be empty')
        end

        context 'when a name is passed in via a query param' do
          let(:path) { '/my-type?name=smurf' }

          it 'creates a new named config' do
            post path, content, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(201)
            expect(Bosh::Director::Models::Config.first.name).to eq('smurf')
          end

          it 'creates a new event and add name to event context' do
            expect {
              post path, content, {'CONTENT_TYPE' => 'text/yaml'}
            }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)

            event = Bosh::Director::Models::Event.first
            expect(event.object_type).to eq('config')
            expect(event.object_name).to eq('smurf')
            expect(event.action).to eq('create')
            expect(event.user).to eq('admin')
          end
        end
      end

      describe 'when user has readonly access' do
        before { basic_authorize 'reader', 'reader' }

        it 'denies access' do
          expect(post('/my-type', content, {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
        end
      end
    end
  end
end
