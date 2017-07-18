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

        def find_by_type_and_name(type, name = nil, limit:)
          name ||= ''
          Bosh::Director::Models::Config
              .where(type: type, name: name)
              .order(Sequel.desc(:id))
              .limit(limit)
              .all
        end
      end
    end
  end
end
