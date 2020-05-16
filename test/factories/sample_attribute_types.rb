# SampleAttributeType
Factory.define(:integer_sample_attribute_type, class: SampleAttributeType) do |f|
  f.sequence(:title) { |n| "Integer attribute type #{n}" }
  f.base_type Seek::Samples::BaseType::INTEGER
end

Factory.define(:string_sample_attribute_type, class: SampleAttributeType) do |f|
  f.sequence(:title) { |n| "String attribute type #{n}" }
  f.base_type Seek::Samples::BaseType::STRING
end

Factory.define(:xxx_string_sample_attribute_type, parent: :string_sample_attribute_type) do |f|
  f.regexp '.*xxx.*'
end

Factory.define(:float_sample_attribute_type, class: SampleAttributeType) do |f|
  f.sequence(:title) { |n| "Float attribute type #{n}" }
  f.base_type Seek::Samples::BaseType::FLOAT
end

Factory.define(:datetime_sample_attribute_type, class: SampleAttributeType) do |f|
  f.sequence(:title) { |n| "DateTime attribute type #{n}" }
  f.base_type Seek::Samples::BaseType::DATE_TIME
end

Factory.define(:text_sample_attribute_type, class: SampleAttributeType) do |f|
  f.sequence(:title) { |n| "Text attribute type #{n}" }
  f.base_type Seek::Samples::BaseType::TEXT
end

Factory.define(:boolean_sample_attribute_type, class: SampleAttributeType) do |f|
  f.sequence(:title) { |n| "Boolean attribute type #{n}" }
  f.base_type Seek::Samples::BaseType::BOOLEAN
end

Factory.define(:strain_sample_attribute_type, class: SampleAttributeType) do |f|
  f.sequence(:title) { |n| "Strain attribute type #{n}" }
  f.base_type Seek::Samples::BaseType::SEEK_STRAIN
end

Factory.define(:sample_sample_attribute_type, class: SampleAttributeType) do |f|
  f.sequence(:title) { |n| "Sample attribute type #{n}" }
  f.base_type Seek::Samples::BaseType::SEEK_SAMPLE
end

# very simple persons name, must be 2 words, first and second word starting with capital with all letters
Factory.define(:full_name_sample_attribute_type, parent: :string_sample_attribute_type) do |f|
  f.regexp '[A-Z][a-z]+[ ][A-Z][a-z]+'
  f.title 'Full name'
end

# positive integer
Factory.define(:age_sample_attribute_type, parent: :integer_sample_attribute_type) do |f|
  f.regexp '^[1-9]\d*$'
  f.title 'Age'
end

# positive float
Factory.define(:weight_sample_attribute_type, parent: :float_sample_attribute_type) do |f|
  f.regexp '^[1-9]\d*[.][1-9]\d*$'
  f.title 'Weight'
end

# uk postcode - taken from http://regexlib.com/REDetails.aspx?regexp_id=260
Factory.define(:postcode_sample_attribute_type, parent: :string_sample_attribute_type) do |f|
  f.regexp '^([A-PR-UWYZ0-9][A-HK-Y0-9][AEHMNPRTVXY0-9]?[ABEHMNPRVWXY0-9]? {1,2}[0-9][ABD-HJLN-UW-Z]{2}|GIR 0AA)$'
  f.title 'Post Code'
end

Factory.define(:address_sample_attribute_type, parent: :text_sample_attribute_type) do |f|
  f.title 'Address'
end

Factory.define(:controlled_vocab_attribute_type, class: SampleAttributeType) do |f|
  f.sequence(:title) { |n| "CV attribute type #{n}" }
  f.base_type 'CV'
end

# SampleControlledVocabTerm
Factory.define(:sample_controlled_vocab_term) do |_f|
end

# SampleControlledVocab
Factory.define(:apples_sample_controlled_vocab, class: SampleControlledVocab) do |f|
  f.sequence(:title) { |n| "apples controlled vocab #{n}" }
  f.after_build do |vocab|
    vocab.sample_controlled_vocab_terms << Factory.build(:sample_controlled_vocab_term, label: 'Granny Smith')
    vocab.sample_controlled_vocab_terms << Factory.build(:sample_controlled_vocab_term, label: 'Golden Delicious')
    vocab.sample_controlled_vocab_terms << Factory.build(:sample_controlled_vocab_term, label: 'Bramley')
    vocab.sample_controlled_vocab_terms << Factory.build(:sample_controlled_vocab_term, label: "Cox's Orange Pippin")
  end
end
