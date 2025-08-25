RSpec.describe Geordi::Git do
  before do
    ENV['GEORDI_TESTING'] = 'true'
    ENV['GEORDI_TESTING_GIT_COMMITS'] = "first example commit\n[W-365] Linear Issue Commit\nCommit with id [A-123] that gets ignored"
  end

  describe '#extract_linear_issue_id' do
    it 'returns extracted issue ids from the beginning of the commit message' do
      expect(described_class.extract_linear_issue_id('test', 'main')).to eq  ["W-365"]
    end
  end
end
