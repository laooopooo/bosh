require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ConfigsController < BaseController

      get '/:type', scope: :read do
        if params['limit'].nil? || params['limit'].empty?
          raise ValidationMissingField, "'limit' is required"
        end

        begin
          limit = Integer(params['limit'])
        rescue ArgumentError
          raise ValidationInvalidType, "'limit' is invalid: '#{params['limit']}' is not an integer"
        end

        configs = Bosh::Director::Api::ConfigManager.new.find_by_type_and_name(
            params['type'],
            params['name'],
            limit: limit,
            content: true
        )

        result = configs.map do |config|
          { content: config.content }
        end

        json_encode(result)
      end
    end
  end
end
