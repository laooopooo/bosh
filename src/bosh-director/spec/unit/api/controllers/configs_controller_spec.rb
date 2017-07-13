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

          get '/my-type?name=some-name&limit=2&content=true'

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

          let(:url_path) { '/my-type?limit=10&content=true' }

          it 'uses the default name' do
            get url_path

            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq('config-with-empty-name')
          end
        end

        context 'when not all required parameters are provided' do
          context "when 'limit' is not specified" do
            let(:url_path) { '/my-type?name=some-name&content=true' }

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

          context "when 'type' is not specified" do
            let(:url_path) { '/?name=some-name&limit=1' }

            it 'returns STATUS 404' do
              get url_path

              expect(last_response.status).to eq(404)
            end
          end
        end
      end

      context 'without an authenticated user' do
        it 'denies access' do
          expect(get('/').status).to eq(401)
        end
      end

      context 'when user is reader' do
        before { basic_authorize('reader', 'reader') }

        it 'permits access' do
          expect(get('/my-type?limit=1').status).to eq(200)
        end
      end
    end
  end
end
