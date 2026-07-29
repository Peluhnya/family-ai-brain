class HotwireNativeController < ApplicationController
  def configuration
    expires_in 1.hour, public: true

    render json: {
      settings: {
        screenshots_enabled: true
      },
      rules: [
        {
          patterns: [ ".*" ],
          properties: {
            context: "default",
            pull_to_refresh_enabled: true
          }
        },
        {
          patterns: [ "/users/sign_in.*", "/users/sign_up.*", "/users/password.*" ],
          properties: {
            context: "modal",
            pull_to_refresh_enabled: false
          }
        },
        {
          patterns: [ "/.*(?:new|edit)$" ],
          properties: {
            context: "modal"
          }
        }
      ]
    }
  end
end
