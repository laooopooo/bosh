module Bosh
  module Director
    module Api
      class ConfigManager
        def create(type, name, config_yaml)
          config = Bosh::Director::Models::Config.new(
              type: type,
              name: name,
              content: config_yaml
          )
          config.save
        end

        def list(type: nil, name: nil)
          dataset = Bosh::Director::Models::Config
          dataset = dataset.where(type: type) if type
          dataset = dataset.where(name: name) if name
          dataset.distinct.select(:type, :name).order(Sequel.desc(:id)).all
        end

        def find_by_type_and_name(type, name = nil)
          name ||= ''
          Bosh::Director::Models::Config
              .where(type: type, name: name)
              .order(Sequel.desc(:id))
              .first
        end
      end
    end
  end
end
