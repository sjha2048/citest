# Annotation
Factory.define :annotation do |f|
  f.sequence(:value) { |n| "anno #{n}" }
  f.association :source, factory: :person
  f.attribute_name 'annotation'
end

Factory.define :tag, parent: :annotation do |f|
  f.attribute_name 'tag'
end

Factory.define :expertise, parent: :annotation do |f|
  f.attribute_name 'expertise'
end

Factory.define :funding_code, parent: :annotation do |f|
  f.attribute_name 'funding_code'
end

Factory.define :tool, parent: :annotation do |f|
  f.attribute_name 'tool'
end

# TextValue
Factory.define :text_value do |f|
  f.sequence(:text) { |n| "value #{n}" }
end

# Discipline
Factory.define :discipline do |f|
  f.sequence(:title) { |n| "Discipline #{n}" }
end

# Worksheet
Factory.define :worksheet do |f|
  f.content_blob { Factory.build(:spreadsheet_content_blob, asset: Factory(:data_file)) }
  f.last_row 10
  f.last_column 10
end

# CellRange
Factory.define :cell_range do |f|
  f.cell_range 'A1:B3'
  f.association :worksheet
end

# Scale
Factory.define :scale do |f|
  f.sequence(:title) { |n| "scale #{n}" }
  f.sequence(:pos) { |n| n }
  f.sequence(:key) { |n| "scale_key_#{n}" }
  f.sequence(:image_name) { |n| "image_#{n}" }
end
