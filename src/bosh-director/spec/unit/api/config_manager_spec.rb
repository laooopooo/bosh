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

  describe '#list' do
    before do
      Bosh::Director::Models::Config.make
      Bosh::Director::Models::Config.make(name: 'other-name')
      Bosh::Director::Models::Config.make(name: 'new-name', type: 'new-type')
    end

    it 'returns names and types of all configs' do
      configs = manager.list
      expect(configs.count).to eq(3)
    end

    context 'when filtering' do
      it 'returns only the elements with the given name' do
        configs = manager.list(name: 'other-name')
        expect(configs.count).to eq(1)
      end

      it 'returns only the elements with the given type' do
        configs = manager.list(type: 'my-type')
        expect(configs.count).to eq(2)
      end

      it 'returns no elements with no matches' do
        configs = manager.list(type: 'foo', name: 'bar')
        expect(configs.count).to eq(0)
      end
    end
  end

  describe '#find_by_type_and_name' do
    it 'returns the config model' do
      Bosh::Director::Models::Config.make(content: 'some-yaml')

      config = manager.find_by_type_and_name(type, name)

      expect(config.content).to eq('some-yaml')
    end

    it 'returns the latest config' do
      Bosh::Director::Models::Config.make(
        created_at: Time.now - 3.days
      )

      second_config = Bosh::Director::Models::Config.make(
        created_at: Time.now - 2.days
      )

      config = manager.find_by_type_and_name(type, name)

      expect(config.id).to eq(second_config.id)
    end

    context 'when there is no config with given type and name' do
      it 'returns nil' do
        config = manager.find_by_type_and_name(type, name)
        expect(config).to eq(nil)
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
        config = manager.find_by_type_and_name(type)
        expect(config.id).to eq(empty_string_name_config.id)
      end

      it 'uses the default empty string for nil' do
        config = manager.find_by_type_and_name(type, nil)
        expect(config.id).to eq(empty_string_name_config.id)
      end
    end
  end
end
