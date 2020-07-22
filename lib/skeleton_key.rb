# frozen_string_literal: true

require 'skeleton_key/version'
require 'keycloak'
require 'json'
require 'skeleton_key/config'

module SkeletonKey
  class Error < StandardError; end
  class << self
    def config
      @config ||= Config.new
    end
    def configure
      yield @config
    end
  end
  class User
    # Patch code
    # TODO: Fix Keycloak gem lib/keycloak.rb:198
    Keycloak.proc_cookie_token = -> {}


    # Authorization header format: "Bearer <access_token>"
    def self.from_headers(headers)
      auth_header = headers['Authorization']
      unless auth_header
        raise Error.new('Missing Authorization header')
      end

      access_token = auth_header.split(' ')[1]
      new(access_token)
    end

    def self.sign_in(username, password)
      json = Keycloak::Client.get_token(username, password)
      full_token = JSON.parse(json, symbolize_names: true)
      access_token = full_token[:access_token]
      refresh_token = full_token[:refresh_token]
      self.new(access_token, refresh_token)
    end

    def self.service_account_user
      sk_client_id = SkeletonKey.config.client_id
      sk_client_secret = SkeletonKey.config.client_secret
      if sk_client_id && sk_client_secret
        json = Keycloak::Client.get_token_by_client_credentials(sk_client_id, sk_client_secret)
      else
        json = Keycloak::Client.get_token_by_client_credentials
      end
      full_token = JSON.parse(json, symbolize_names: true)
      access_token = full_token[:access_token]
      refresh_token = full_token[:refresh_token]
      self.new(access_token, refresh_token, client_id: sk_client_id, client_secret: sk_client_secret)
    end

    attr_accessor :access_token, :refresh_token, :client_id, :client_secret

    DEFAULT_OPTS = {
      client_id: SkeletonKey.config.client_id,
      client_secret: SkeletonKey.config.client_secret
    }.freeze

    def initialize(access_token, refresh_token = nil, opts = {})
      @access_token = access_token
      @refresh_token = refresh_token
      opts.merge!(DEFAULT_OPTS) 
      @client_id = opts[:client_id]
      @client_secret = opts[:client_secret]
    end

    def refresh_token!
      self.access_token = Keycloak::Client.get_token_by_refresh_token(refresh_token, client_id, client_secret)
    rescue RestClient::BadRequest, NoMethodError
      self.access_token = nil
    end

    def sign_out!
      # Urrghh. maybe better change those params to a hash?
      Keycloak::Client.logout('', refresh_token, client_id, client_secret)
    end

    def info
      return @info if @info

      self.signed_in?
      json = Keycloak::Client.get_userinfo(access_token)
      @info = JSON.parse(json, symbolize_names: true)
    rescue RestClient::BadRequest, NoMethodError, JSON::JSONError
      {}
    end

    def id
      info[:sub]
    end

    def has_role?(role_name)
      Keycloak::Client.has_role?(role_name, access_token, client_id, client_secret)
    end

    def signed_in?
      retried ||= false
      res = Keycloak::Client.user_signed_in?(access_token, client_id, client_secret)
      unless res
        raise RuntimeError
      end

      res
    rescue RuntimeError, RestClient::BadRequest
      unless retried
        retried = true
        refresh_token!
        retry
      end
      false
    end
  end
end
