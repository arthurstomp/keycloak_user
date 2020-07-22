# frozen_string_literal: true

require_relative 'lib/skeleton_key/version'

Gem::Specification.new do |spec|
  spec.name          = 'skeleton_key'
  spec.version       = SkeletonKey::VERSION
  spec.authors       = ['stomp']
  spec.email         = ['arthurstomp@gmail.com']

  spec.summary       = 'Utility user class to use with Keycloak'
  spec.description   = ''
  spec.homepage      = 'https://github.com/arthurstomp/skeleton_key'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  # spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/arthurstomp/skeleton_key'
  spec.metadata['changelog_uri'] = 'https://github.com/arthurstomp/skeleton_key'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.add_runtime_dependency 'keycloak', ">= 3.2.1"
end
