is_root = false unless local_assigns.has_key?(:is_root)

parent_xml.tag! 'document', core_xlink(document).merge(is_root ? xml_root_attributes : {}) do
  render partial: 'api/standard_elements',locals: { parent_xml: parent_xml, is_root: is_root, object: document }
  associated_resources_xml parent_xml, document if is_root
end
