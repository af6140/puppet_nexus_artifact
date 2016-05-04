require 'spec_helper'
describe 'nexus_artifact' do
  context 'with defaults for all parameters' do
  	it { should compile.with_all_deps }
    it { should contain_class('nexus_artifact') }
  end
end
