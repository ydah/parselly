# frozen_string_literal: true

RSpec.describe Parselly do
  describe '.parse' do
    it 'parses a selector via module-level API' do
      ast = described_class.parse('div#main.content')

      expect(ast).not_to be_nil
      expect(ast).to respond_to(:type)
    end
  end
end
