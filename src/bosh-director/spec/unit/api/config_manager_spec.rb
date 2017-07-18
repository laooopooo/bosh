require 'spec_helper'

describe Bosh::Director::Api::ConfigManager do
  subject(:manager) { Bosh::Director::Api::ConfigManager.new }
  let(:valid_yaml) { YAML.dump("---\n{key: value") }
  let(:type) { 'my-type' }
  let(:name) { 'some-name' }

  describe '#create' do
    it 'saves the config' do
      expect {
        manager.create(type, name, valid_yaml)
      }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

      config = Bosh::Director::Models::Config.first
      expect(config.created_at).to_not be_nil
      expect(config.content).to eq(valid_yaml)
    end
  end

  describe '#find_by_type_and_name' do
    it 'returns the content' do
      Bosh::Director::Models::Config.make(content: 'some-yaml')

      configs = manager.find_by_type_and_name(type, name, limit: 1)

      expect(configs.count).to eq(1)
      expect(configs.first.content).to eq('some-yaml')
    end

    it 'returns the specified number of configs' do
      Bosh::Director::Models::Config.make(
        created_at: Time.now - 3.days
      )

      second_config = Bosh::Director::Models::Config.make(
        created_at: Time.now - 2.days
      )

      configs = manager.find_by_type_and_name(type, name, limit: 1)

      expect(configs.count).to eq(1)
      expect(configs.first.id).to eq(second_config.id)
    end

    context 'when multiple matches' do
      it 'returns a list of matching configs ordered by time descending' do
        old_config = Bosh::Director::Models::Config.make(
          created_at: Time.now - 3.days
        )

        new_config = Bosh::Director::Models::Config.make(
          created_at: Time.now - 2.days
        )

        configs = manager.find_by_type_and_name(type, name, limit: 10)

        expect(configs.count).to eq(2)
        expect(configs[0].id).to eq(new_config.id)
        expect(configs[1].id).to eq(old_config.id)
      end
    end

    context 'when there are no configs with given type and name' do
      it 'returns an empty array' do
        configs = manager.find_by_type_and_name(type, name, limit: 1)

        expect(configs.class).to be(Array)
        expect(configs).to eq([])
      end
    end

    context 'when "name" parameter is not used' do
      let!(:empty_string_name_config) do
        Bosh::Director::Models::Config.make(name: '')
      end

      before do
        Bosh::Director::Models::Config.make(name: 'with-some-name')
      end

      it 'uses the default empty string' do
        configs = manager.find_by_type_and_name(type, limit: 1)
        expect(configs.count).to eq(1)
        expect(configs[0].id).to eq(empty_string_name_config.id)
      end

      it 'uses the default empty string' do
        configs = manager.find_by_type_and_name(type, nil, limit: 1)
        expect(configs.count).to eq(1)
        expect(configs[0].id).to eq(empty_string_name_config.id)
      end
    end
  end
end
