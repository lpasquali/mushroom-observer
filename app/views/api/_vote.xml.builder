xml.tag!(tag,
  :id => object.id,
  :url => object.show_url,
  :type => 'vote'
) do
  xml_confidence_level(xml, :confidence, object.value)
  if detail
    xml_datetime(xml, :created_at, object.created_at)
    xml_datetime(xml, :updated_at, object.updated_at)
    xml_minimal_object(xml, :owner, User, object.user_id) if object.user == User.current or !object.anonymous?
    xml_minimal_object(xml, :naming, Naming, object.naming_id)
    xml_minimal_object(xml, :observation, Observation, object.observation_id)
  end
end
