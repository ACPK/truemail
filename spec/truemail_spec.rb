# frozen_string_literal: true

RSpec.describe Truemail do
  let(:email) { FFaker::Internet.email }

  describe 'defined constants' do
    specify { expect(described_class).to be_const_defined(:INCOMPLETE_CONFIG) }
    specify { expect(described_class).to be_const_defined(:NOT_CONFIGURED) }
    specify { expect(described_class).to be_const_defined(:VERSION) }
    specify { expect(described_class).to be_const_defined(:Configuration) }
    specify { expect(described_class).to be_const_defined(:Worker) }
    specify { expect(described_class).to be_const_defined(:Wrapper) }
    specify { expect(described_class).to be_const_defined(:Auditor) }
    specify { expect(described_class).to be_const_defined(:Validator) }
    specify { expect(described_class).to be_const_defined(:ConfigurationError) }
    specify { expect(described_class).to be_const_defined(:ArgumentError) }
    specify { expect(described_class).to be_const_defined(:RegexConstant) }
    specify { expect(described_class).to be_const_defined(:Audit) }
    specify { expect(described_class).to be_const_defined(:Validate) }
  end

  describe '.configure' do
    subject(:configure) { described_class.configure(&config_block) }

    let(:config_block) {}

    context 'without block' do
      specify { expect(configure).to be_nil }
      specify { expect { configure }.not_to change(described_class, :configuration) }
    end

    context 'with block' do
      context 'without required parameter' do
        let(:config_block) { configuration_block }

        specify do
          expect { configure }
            .to raise_error(Truemail::ConfigurationError, Truemail::INCOMPLETE_CONFIG)
        end
      end

      context 'with valid required parameter' do
        let(:config_block) { configuration_block(verifier_email: email) }

        specify do
          expect { configure }
            .to change(described_class, :configuration)
            .from(nil).to(be_instance_of(Truemail::Configuration))
        end

        it 'sets attributes into configuration instance' do
          expect(configure).to be_an_instance_of(Truemail::Configuration)
          expect(described_class.configuration.verifier_email).to eq(email)
        end
      end
    end
  end

  describe '.reset_configuration!' do
    before { described_class.configure(&configuration_block(verifier_email: email)) }

    specify do
      expect { described_class.reset_configuration! }
        .to change(described_class, :configuration)
        .from(be_instance_of(Truemail::Configuration)).to(nil)
    end
  end

  describe '.configuration' do
    subject(:configuration) { described_class.configuration }

    before do
      described_class.configure(&configuration_block(
        verifier_email: email,
        verifier_domain: domain
        )
      )
    end

    let(:domain) { FFaker::Internet.domain_name }
    let(:new_email) { FFaker::Internet.email }
    let(:new_domain) { FFaker::Internet.domain_name }
    let(:new_regex_pattern) { /\A+.\z/ }
    let(:new_smtp_error_body_pattern) { /\A\d+\z/ }

    specify { expect(configuration).to be_instance_of(Truemail::Configuration) }

    it 'accepts to rewrite current configuration settings' do
      expect do
        configuration.tap(&configuration_block(
          verifier_email: new_email,
          verifier_domain: new_domain,
          email_pattern: new_regex_pattern,
          smtp_error_body_pattern: new_smtp_error_body_pattern
          )
        )
      end
      .to change(configuration, :verifier_email).from(email).to(new_email)
      .and change(configuration, :verifier_domain).from(domain).to(new_domain)
      .and change(configuration, :email_pattern)
      .from(Truemail::RegexConstant::REGEX_EMAIL_PATTERN).to(new_regex_pattern)
      .and change(configuration, :smtp_error_body_pattern)
      .from(Truemail::RegexConstant::REGEX_SMTP_ERROR_BODY_PATTERN).to(new_smtp_error_body_pattern)
    end
  end

  describe '.validate' do
    context 'when configuration not set' do
      specify do
        expect { described_class.validate(email) }
          .to raise_error(Truemail::ConfigurationError, Truemail::NOT_CONFIGURED)
      end
    end

    context 'when configuration successfully set' do
      before do
        described_class.configure do |config|
          config.verifier_email = 'valdyslav.trotsenko@rubygarage.org'
          config.connection_timeout = 1
          config.response_timeout = 1
        end
      end

      specify do
        allow(Truemail::Validate::Smtp).to receive(:check).and_return(true)
        expect(described_class.validate('nonexistent_email@rubygarage.org'))
          .to be_an_instance_of(Truemail::Validator)
      end

      describe 'integration tests' do
        context 'when checks real email' do
          specify do
            expect(described_class.validate('vladyslav.trotsenko@rubygarage.org').result.valid?).to be(true)
          end
        end

        context 'when checks fake email' do
          specify do
            expect(described_class.validate('nonexistent_email@rubygarage.org').result.valid?).to be(false)
          end
        end
      end
    end
  end

  describe '.valid?' do
    subject(:valid_helper) { described_class.valid?(email) }

    before { described_class.configure { |config| config.verifier_email = email } }

    it 'returns boolean from validator result instance' do
      allow(Truemail::Validate::Smtp).to receive(:check).and_return(true)
      allow_any_instance_of(Truemail::Validator::Result).to receive(:valid?).and_return(true)
      expect(valid_helper).to be(true)
    end
  end

  describe '.host_audit' do
    subject(:host_audit) { described_class.host_audit }

    before do
      described_class.configure { |config| config.verifier_email = email }
      allow(Truemail::Auditor).to receive(:run).and_call_original
    end

    it 'returns auditor instance' do
      expect(host_audit).to be_an_instance_of(Truemail::Auditor)
    end

    it 'runs checks for auditor result instance' do
      expect(Truemail::Audit::Ptr).to receive(:check)
      host_audit
    end
  end
end
