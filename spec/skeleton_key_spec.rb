# frozen_string_literal: true

RSpec.describe SkeletonKey do
  it 'has a version number' do
    expect(SkeletonKey::VERSION).not_to be nil
  end

  describe SkeletonKey::User do
    let(:username) { 'test' }
    let(:password) { 'test' }
    let(:user_id) { 'test_id' }
    let(:access_token) { 'access_token' }
    let(:refresh_token) { 'refresh_token' }
    let(:user_role) { 'test' }
    let!(:ku) { described_class.new(access_token, refresh_token) }

    describe '::from_headers' do
      let(:headers) { { 'Authorization' => "Bearer #{access_token}" } }

      it 'raises Error if Authorization header is not present' do
        expect { described_class.from_headers({}) }.to raise_error(SkeletonKey::Error)
      end

      it 'return an instance with access_token' do
        ins = described_class.from_headers(headers)
        expect(ins.access_token).to eq(access_token)
      end
    end

    describe '::sign_in' do
      before do
        allow(Keycloak::Client).to receive(:get_token).with(username, password) do
          {
            access_token: access_token,
            refresh_token: refresh_token
          }.to_json
        end
      end

      it 'calls for Keycloak::Client#get_token' do
        described_class.sign_in(username, password)
        expect(Keycloak::Client).to have_received(:get_token).with(username, password)
      end

      it 'return an instance with access_token' do
        ins = described_class.sign_in(username, password)
        expect(ins.access_token).to eq(access_token)
      end

      it 'return an instance with refresh_token' do
        ins = described_class.sign_in(username, password)
        expect(ins.refresh_token).to eq(refresh_token)
      end
    end

    describe '::service_account_user' do
      before do
        allow(Keycloak::Client).to receive(:get_token_by_client_credentials) do
          {
            access_token: access_token,
            refresh_token: refresh_token
          }.to_json
        end
      end

      it 'calls for Keycloak::Client#get_token_by_client_credentials' do
        described_class.service_account_user
        expect(Keycloak::Client).to have_received(:get_token_by_client_credentials)
      end

      it 'return an instance with access_token' do
        ins = described_class.service_account_user
        expect(ins.access_token).to eq(access_token)
      end

      it 'return an instance with refresh_token' do
        ins = described_class.service_account_user
        expect(ins.refresh_token).to eq(refresh_token)
      end
    end

    describe '#refresh_token!' do
      before do
        allow(Keycloak::Client).to receive(:get_token_by_refresh_token).with(refresh_token) do
          access_token
        end
      end

      it 'calls for Keycloak::Client#get_token_by_refresh_token' do
        ku.refresh_token!
        expect(Keycloak::Client).to have_received(:get_token_by_refresh_token).with(refresh_token)
      end

      %w[RestClient::BadRequest NoMethodError].each do |err|
        it "return {} if error #{err} occour" do
          klass = Kernel.const_get(err)
          allow(Keycloak::Client).to receive(:get_token_by_refresh_token).and_raise(klass)
          expect(ku.refresh_token!).to eq(nil)
        end
      end
    end

    describe '#sign_out!' do
      before do
        allow(Keycloak::Client).to receive(:logout).with('', refresh_token)
      end

      it 'calls for Keycloak::Client#get_token_by_refresh_token' do
        ku.sign_out!
        expect(Keycloak::Client).to have_received(:logout).with('', refresh_token)
      end
    end

    describe '#info' do
      before do
        allow(Keycloak::Client).to receive(:get_userinfo).with(access_token).and_return({sub: user_id}.to_json)
        allow(Keycloak::Client).to receive(:user_signed_in?).with(access_token).and_return(true)
      end

      it 'calls for Keycloak::Client#get_userinfo' do
        ku.info
        expect(Keycloak::Client).to have_received(:get_userinfo).with(access_token)
      end

      %w[RestClient::BadRequest NoMethodError JSON::JSONError].each do |err|
        it "return {} if error #{err} occour" do
          klass = Kernel.const_get(err)
          allow(ku).to receive(:signed_in?).and_raise(klass)
          expect(ku.info).to eq({})
        end
      end
    end

    describe 'id' do
      it 'is #info[:sub]' do
        ku = described_class.new(nil)
        allow(ku).to receive(:info) { { sub: user_id } }
        expect(ku.id).to eq(user_id)
      end
    end

    describe '#has_role?' do
      before do
        allow(Keycloak::Client).to receive(:has_role?).with(user_role, access_token)
      end

      it 'calls for Keycloak::Client.has_role?' do
        ku.has_role?('test')
        expect(Keycloak::Client).to have_received(:has_role?).with(user_role, access_token)
      end
    end

    describe '#signed_in?' do
      it 'returns true if Keycloak::Client says so' do
        allow(Keycloak::Client).to receive(:user_signed_in?).and_return(true)
        expect(ku.signed_in?).to eq(true)
      end

      it 'returns false if Keycloak::Client says so' do
        allow(Keycloak::Client).to receive(:get_token_by_refresh_token).and_return('test')
        allow(Keycloak::Client).to receive(:user_signed_in?).and_return(false)
        expect(ku.signed_in?).to eq(false)
      end

      it 'try to refresh_token' do
        allow(Keycloak::Client).to receive(:user_signed_in?).and_return(false)
        allow(ku).to receive(:refresh_token!)
        ku.signed_in?
        expect(ku).to have_received(:refresh_token!)
      end

      it 'returns false if Keycloak::Client raises RestClient::BadRequest' do
        allow(Keycloak::Client).to receive(:get_token_by_refresh_token).and_return('test')
        allow(Keycloak::Client).to receive(:user_signed_in?).and_raise(RestClient::BadRequest)
        expect(ku.signed_in?).to eq(false)
      end
    end

  end
end
