is_root = false unless local_assigns.has_key?(:is_root)

parent_xml.tag! "sop",
core_xlink(sop).merge(is_root ? xml_root_attributes : {}) do
  render :partial=>"api/standard_elements",:locals=>{:parent_xml => parent_xml,:is_root=>is_root,:object=>sop}
  if (is_root)
    associated_resources_xml parent_xml,sop
  end
end