require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ConfigsController < BaseController

      get '/', scope: :admin do
        configs = Bosh::Director::Api::ConfigManager.new.list(name: params['name'], type: params['type'])
        result = configs.map do |config|
          { name: config.name, type: config.type }
        end
        json_encode(result)
      end

      get '/:type', scope: :read do
        config = Bosh::Director::Api::ConfigManager.new.find_by_type_and_name(
            params['type'],
            params['name']
        )

        result = { content: nil }
        result = { content: config.content } if config
        json_encode(result)
      end

      post '/:type', :consumes => :yaml do
        config_name = params['name'].nil? ? '' : params['name']
        manifest_text = request.body.read
        begin
          validate_manifest_yml(manifest_text, nil)
          Bosh::Director::Api::ConfigManager.new.create(params['type'], config_name, manifest_text)
          create_event(config_name)
        rescue => e
          create_event(config_name, e)
          raise e
        end

        status(201)
      end

      private

      def create_event(name, error = nil)
        @event_manager.create_event({
          user:        current_user,
          action:      'create',
          object_type: 'config',
          object_name: name,
          error:       error
        })
      end
    end
  end
end
