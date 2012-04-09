# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../boot')

class SpeciesListControllerTest < FunctionalTestCase

  # Score for one new name.
  def v_nam; 10; end

  # Score for one species list.
  def v_spl; 5; end

  # Score for one observation:
  #   species_list entry  1
  #   observation         1
  #   naming              1
  #   vote                1
  def v_obs; 4; end

  def spl_params(spl)
    params = {
      :id => spl.id,
      :species_list => {
        :place_name => spl.place_name,
        :title => spl.title,
        "when(1i)" => spl.when.year.to_s,
        "when(2i)" => spl.when.month.to_s,
        "when(3i)" => spl.when.day.to_s,
        :notes => spl.notes
      },
      :list => { :members => "" },
      :checklist_data => {},
      :member => { :notes => "" },
    }
  end

################################################################################

  def test_list_species_lists
    get_with_dump(:list_species_lists)
    assert_response('list_species_lists')
  end

  def test_show_species_list
    # Show empty list with no one logged in.
    get_with_dump(:show_species_list, :id => 1)
    assert_response('show_species_list')

    # Show same list with non-owner logged in.
    login('mary')
    get_with_dump(:show_species_list, :id => 1)
    assert_response('show_species_list')

    # Show non-empty list with owner logged in.
    get_with_dump(:show_species_list, :id => 3)
    assert_response('show_species_list')
  end

  def test_species_lists_by_title
    get_with_dump(:species_lists_by_title)
    assert_response('list_species_lists')
  end

  def test_species_lists_by_user
    get_with_dump(:species_lists_by_user, :id => @rolf.id)
    assert_response('list_species_lists')
  end

  def test_destroy_species_list
    spl = species_lists(:first_species_list)
    assert(spl)
    id = spl.id
    params = { :id => id.to_s }
    assert_equal("rolf", spl.user.login)
    requires_user(:destroy_species_list, [:show_species_list], params)
    assert_response(:action => :list_species_lists)
    assert_raises(ActiveRecord::RecordNotFound) do
      SpeciesList.find(id)
    end
  end

  def test_manage_species_lists
    obs = observations(:coprinus_comatus_obs)
    params = { :id => obs.id.to_s }
    requires_login(:manage_species_lists, params)
    assert_block('Missing species lists!') {
      assigns(:all_lists).length > 0 rescue nil
    }
  end

  def test_add_observation_to_species_list
    sp = species_lists(:first_species_list)
    obs = observations(:coprinus_comatus_obs)
    assert(!sp.observations.member?(obs))
    params = { :species_list => sp.id, :observation => obs.id }
    requires_login(:add_observation_to_species_list, params)
    assert_response(:action => :manage_species_lists)
    assert(sp.reload.observations.member?(obs))
  end

  def test_remove_observation_from_species_list
    spl = species_lists(:unknown_species_list)
    obs = observations(:minimal_unknown)
    assert(spl.observations.member?(obs))
    params = { :species_list => spl.id, :observation => obs.id }
    owner = spl.user.login
    assert_not_equal('rolf', owner)

    # Try with non-owner (can't use requires_user since failure is a redirect)
    # effectively fails and gets redirected to show_species_list
    requires_login(:remove_observation_from_species_list, params)
    assert_response(:action => :show_species_list)
    assert(spl.reload.observations.member?(obs))

    login owner
    get_with_dump(:remove_observation_from_species_list, params)
    assert_response(:action => "manage_species_lists")
    assert(!spl.reload.observations.member?(obs))
  end

  # ----------------------------
  #  Create lists.
  # ----------------------------

  def test_create_species_list
    requires_login(:create_species_list)
    assert_form_action(:action => 'create_species_list')
  end

  # Test constructing species lists in various ways.
  def test_construct_species_list
    list_title = "List Title"
    params = {
      :list => { :members => names(:coprinus_comatus).text_name },
      :member => { :notes => "" },
      :species_list => {
        :place_name => "Burbank, California, USA",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      }
    }
    post_requires_login(:create_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_spl + v_obs, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    assert(spl.name_included(names(:coprinus_comatus)))
    obs = spl.observations.first
    assert_equal(Vote.maximum_vote, obs.namings.first.votes.first.value)
    assert_equal('', obs.notes.to_s)
    assert_equal(nil, obs.lat)
    assert_equal(nil, obs.long)
    assert_equal(nil, obs.alt)
    assert_equal(false, obs.is_collection_location)
    assert_equal(false, obs.specimen)
  end

  def test_construct_species_list_existing_genus
    agaricus = names(:agaricus)
    list_title = "List Title"
    params = {
      :list => { :members => "#{agaricus.rank} #{agaricus.text_name}" },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :place_name => "Burbank, California, USA",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      }
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_spl + v_obs, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    assert(spl.name_included(agaricus))
  end

  def test_construct_species_list_new_family
    list_title = "List Title"
    rank = :Family
    new_name_str = "Agaricaceae"
    new_list_str = "#{rank} #{new_name_str}"
    assert_nil(Name.find_by_text_name(new_name_str))
    params = {
      :list => { :members => new_list_str },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :place_name => "Burbank, California, USA",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => new_list_str
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    # Creates Agaricaceae, spl, and obs/naming/splentry.
    assert_equal(10 + v_nam + v_spl + v_obs, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    new_name = Name.find_by_text_name(new_name_str)
    assert_not_nil(new_name)
    assert_equal(rank, new_name.rank)
    assert(spl.name_included(new_name))
  end

  # <name> = <name> shouldn't work in construct_species_list
  def test_construct_species_list_synonym
    list_title = "List Title"
    name = names(:macrolepiota_rachodes)
    synonym_name = names(:lepiota_rachodes)
    assert(!synonym_name.deprecated)
    assert_nil(synonym_name.synonym)
    params = {
      :list => { :members => "#{name.text_name} = #{synonym_name.text_name}"},
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :place_name => "Burbank, California, USA",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response('create_species_list')
    assert_equal(10, @rolf.reload.contribution)
    assert(!synonym_name.reload.deprecated)
    assert_nil(synonym_name.synonym)
  end

  def test_construct_species_list_junk
    list_title = "List Title"
    new_name_str = "This is a bunch of junk"
    assert_nil(Name.find_by_text_name(new_name_str))
    params = {
      :list => { :members => new_name_str },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :place_name => "Burbank, California, USA",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => new_name_str
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response('create_species_list')
    assert_equal(10, @rolf.reload.contribution)
    assert_nil(Name.find_by_text_name(new_name_str))
    assert_nil(SpeciesList.find_by_title(list_title))
  end

  def test_construct_species_list_double_space
    list_title = "Double Space List"
    new_name_str = "Lactarius rubidus  (Hesler and Smith) Methven"
    params = {
      :list => { :members => new_name_str },
      :member => { :notes => "" },
      :species_list => {
        :place_name => "Burbank, California, USA",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => new_name_str.squeeze(" ")
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    # Must be creating Lactarius sp as well as L. rubidus (and spl and obs/splentry/naming).
    assert_equal(10 + v_nam*2 + v_spl + v_obs, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    obs = spl.observations.first
    assert_not_nil(obs)
    assert_not_nil(obs.modified)
    name = Name.find_by_search_name(new_name_str.squeeze(" "))
    assert_not_nil(name)
    assert(spl.name_included(name))
  end

  def test_construct_species_list_rankless_taxon
    list_title = "List Title"
    new_name_str = "Agaricaceae"
    assert_nil(Name.find_by_text_name(new_name_str))
    params = {
      :list => { :members => new_name_str },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :place_name => "Burbank, California, USA",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => new_name_str
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    # Creates Agaricaceae, spl, obs/naming/splentry.
    assert_equal(10 + v_nam + v_spl + v_obs, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    new_name = Name.find_by_text_name(new_name_str)
    assert_not_nil(new_name)
    assert_equal(:Genus, new_name.rank)
    assert(spl.name_included(new_name))
  end

  # Rather than repeat everything done for update_species, this construct
  # species just does a bit of everything:
  #   Written in:
  #     Lactarius subalpinus (deprecated, approved)
  #     Amanita baccata      (ambiguous, checked Arora in radio boxes)
  #     New name             (new, approved from previous post)
  #   Checklist:
  #     Agaricus campestris  (checked)
  #     Lactarius alpigenes  (checked, deprecated, approved, checked box for preferred name Lactarius alpinus)
  # Should result in the following list:
  #   Lactarius subalpinus
  #   Amanita baccata Arora
  #   New name
  #   Agaricus campestris
  #   Lactarius alpinus
  #   (but *NOT* L. alpingenes)
  def test_construct_species_list_extravaganza
    deprecated_name = names(:lactarius_subalpinus)
    list_members = [deprecated_name.text_name]
    multiple_name = names(:amanita_baccata_arora)
    list_members.push(multiple_name.text_name)
    new_name_str = "New name"
    list_members.push(new_name_str)
    assert_nil(Name.find_by_text_name(new_name_str))

    checklist_data = {}
    current_checklist_name = names(:agaricus_campestris)
    checklist_data[current_checklist_name.id.to_s] = '1'
    deprecated_checklist_name = names(:lactarius_alpigenes)
    approved_name = names(:lactarius_alpinus)
    checklist_data[deprecated_checklist_name.id.to_s] = '1'

    list_title = "List Title"
    params = {
      :list => { :members => list_members.join("\r\n") },
      :checklist_data => checklist_data,
      :member => { :notes => "" },
      :species_list => {
        :place_name => "Burbank, California, USA",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "6",
        "when(3i)" => "4",
        :notes => "List Notes"
      },
    }
    params[:approved_names] = new_name_str
    params[:chosen_multiple_names] =
        { multiple_name.id.to_s => multiple_name.id.to_s }
    params[:chosen_approved_names] =
        { deprecated_checklist_name.id.to_s => approved_name.id.to_s }
    params[:approved_deprecated_names] =
        [deprecated_name.id.to_s, deprecated_checklist_name.id.to_s].join("\r\n")

    login('rolf')
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    # Creates "New" and "New name", spl, and five obs/naming/splentries.
    assert_equal(10 + v_nam*2 + v_spl + v_obs*5, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert(spl.name_included(deprecated_name))
    assert(spl.name_included(multiple_name))
    assert(spl.name_included(Name.find_by_text_name(new_name_str)))
    assert(spl.name_included(current_checklist_name))
    assert(!spl.name_included(deprecated_checklist_name))
    assert(spl.name_included(approved_name))
  end

  def test_construct_species_list_nonalpha_multiple
    # First try creating it with ambiguous name "Warnerbros bugs-bunny".
    # (There are two such names with authors One and Two, respectively.)
    params = {
      :list => { :members => "\n Warnerbros  bugs-bunny " },
      :member => { :notes => "" },
      :species_list => {
        :place_name => "Burbank, California, USA",
        :title => "Testing nonalphas",
        "when(1i)" => "2008",
        "when(2i)" => "1",
        "when(3i)" => "31",
        :notes => ""
      },
    }
    login('rolf')
    post(:create_species_list, params)
    assert_response('create_species_list')
    assert_equal(10, @rolf.reload.contribution)
    assert_equal("Warnerbros bugs-bunny",
                 @controller.instance_variable_get('@list_members'))
    assert_equal([], @controller.instance_variable_get('@new_names'))
    assert_equal([names(:bugs_bunny_one)],
                 @controller.instance_variable_get('@multiple_names'))
    assert_equal([], @controller.instance_variable_get('@deprecated_names'))

    # Now re-post, having selected Two.
    params = {
      :list => { :members => "Warnerbros bugs-bunny\r\n" },
      :member => { :notes => "" },
      :species_list => {
        :place_name => "Burbank, California, USA",
        :title => "Testing nonalphas",
        "when(1i)" => "2008",
        "when(2i)" => "1",
        "when(3i)" => "31",
        :notes => ""
      },
      :chosen_multiple_names => { names(:bugs_bunny_one).id.to_s => names(:bugs_bunny_two).id },
    }
    post(:create_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_spl + v_obs, @rolf.reload.contribution)
    spl = SpeciesList.last
    assert(spl.name_included(names(:bugs_bunny_two)))
  end

  # Test constructing species lists, tweaking member fields.
  def test_construct_species_list_with_member_fields
    list_title = "List Title"
    params = {
      :list => { :members => names(:coprinus_comatus).text_name },
      :member => {
        :vote  => Vote.minimum_vote,
        :notes => 'member notes',
        :lat   => '12 34 56 N',
        :long  => '78 9 12 W',
        :alt   => '345 ft',
        :is_collection_location => '1',
        :specimen => '1',
      },
      :species_list => {
        :place_name => 'Burbank, California, USA',
        :title => list_title,
        'when(1i)' => '2007',
        'when(2i)' => '3',
        'when(3i)' => '14',
        :notes => 'List Notes'
      }
    }
    post_requires_login(:create_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_spl + v_obs, @rolf.reload.contribution)
    spl = SpeciesList.find_by_title(list_title)
    assert_not_nil(spl)
    assert(spl.name_included(names(:coprinus_comatus)))
    obs = spl.observations.first
    assert_equal(Vote.minimum_vote, obs.namings.first.votes.first.value)
    assert_equal('member notes', obs.notes)
    assert_equal(12.5822, obs.lat)
    assert_equal(-78.1533, obs.long)
    assert_equal(105, obs.alt)
    assert_equal(true, obs.is_collection_location)
    assert_equal(true, obs.specimen)
  end

  # -----------------------------------------------
  #  Test changing species lists in various ways.
  # -----------------------------------------------

  def test_edit_species_list
    spl = species_lists(:first_species_list)
    params = { :id => spl.id.to_s }
    assert_equal('rolf', spl.user.login)
    requires_user(:edit_species_list, :show_species_list, params)
    assert_response('edit_species_list')
    assert_form_action(:action => 'edit_species_list', :id => spl.id.to_s,
                       :approved_where => 'Burbank, California, USA')
  end

  def test_update_species_list_nochange
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    post_requires_user(:edit_species_list, :show_species_list, params,
                       spl.user.login)
    assert_response(:action => :show_species_list)
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
  end

  def test_update_species_list_text_add_multiple
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "Coprinus comatus\r\nAgaricus campestris"
    owner = spl.user.login
    assert_not_equal('rolf', owner)
    login('rolf')
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10, @rolf.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    login owner
    post_with_dump(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_obs*2, spl.user.reload.contribution)
    assert_equal(sp_count + 2, spl.reload.observations.size)
  end

  # This was intended to catch a bug seen in the wild, but it doesn't.
  # The problem was in the HTML, and it requires integration test to show(?)
  def test_update_species_list_add_unknown
    new_name = 'Agaricus nova'
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    old_contribution = @mary.contribution
    params = spl_params(spl)
    params[:list][:members] = new_name
    owner = spl.user.login
    assert_equal('mary', owner)
    login('mary')
    post(:edit_species_list, params)
    assert_response('edit_species_list')
    spl.reload
    assert_equal(sp_count, spl.observations.size)
    params[:approved_names] = new_name
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    spl.reload
    assert_equal(sp_count + 1, spl.observations.size)
    assert_equal(old_contribution + v_nam + v_obs, @mary.reload.contribution)
  end

  def test_update_species_list_text_add
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "Coprinus comatus"
    params[:species_list][:place_name] = "New Place, California, USA"
    params[:species_list][:title] = "New Title"
    params[:species_list][:notes] = "New notes."
    owner = spl.user.login
    assert_not_equal('rolf', owner)
    login('rolf')
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10, @rolf.reload.contribution)
    assert(spl.reload.observations.size == sp_count)
    login owner
    post_with_dump(:edit_species_list, params)
    assert_response(:controller => :location, :action => :create_location)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert_equal("New Place, California, USA", spl.where)
    assert_equal("New Title", spl.title)
    assert_equal("New notes.", spl.notes)
  end

  def test_update_species_list_text_notifications
    spl = species_lists(:first_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "Coprinus comatus\r\nAgaricus campestris"
    login('rolf')
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
  end

  def test_update_species_list_new_name
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "New name"
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
  end

  def test_update_species_list_approved_new_name
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "New name"
    params[:approved_names] = "New name"
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    # Creates 'New', 'New name', observations/splentry/naming.
    assert_equal(10 + v_nam*2 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
  end

  def test_update_species_list_multiple_match
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:amanita_baccata_arora)
    assert(!spl.name_included(name))
    params = spl_params(spl)
    params[:list][:members] = name.text_name
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    assert(!spl.name_included(name))
  end

  def test_update_species_list_chosen_multiple_match
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:amanita_baccata_arora)
    assert(!spl.name_included(name))
    params = spl_params(spl)
    params[:list][:members] = name.text_name
    params[:chosen_multiple_names] = {name.id.to_s => name.id.to_s}
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_deprecated
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:list][:members] = name.text_name
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    assert(!spl.name_included(name))
  end

  def test_update_species_list_approved_deprecated
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:list][:members] = name.text_name
    params[:approved_deprecated_names] = [name.id.to_s]
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_checklist_add
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_alpinus)
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = '1'
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_deprecated_checklist
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = '1'
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, spl.user.reload.contribution)
    assert_equal(sp_count, spl.reload.observations.size)
    assert(!spl.name_included(name))
  end

  def test_update_species_list_approved_deprecated_checklist
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = '1'
    params[:approved_deprecated_names] = [name.id.to_s]
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_approved_renamed_deprecated_checklist
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    approved_name = names(:lactarius_alpinus)
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = '1'
    params[:approved_deprecated_names] = [name.id.to_s]
    params[:chosen_approved_names] =
                { name.id.to_s => approved_name.id.to_s }
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(!spl.name_included(name))
    assert(spl.name_included(approved_name))
  end

  def test_update_species_list_approved_rename
    spl = species_lists(:unknown_species_list)
    sp_count = spl.observations.size
    name = names(:lactarius_subalpinus)
    approved_name = names(:lactarius_alpinus)
    params = spl_params(spl)
    assert(!spl.name_included(name))
    assert(!spl.name_included(approved_name))
    params[:list][:members] = name.text_name
    params[:approved_deprecated_names] = name.id.to_s
    params[:chosen_approved_names] =
                { name.id.to_s => approved_name.id.to_s }
    login(spl.user.login)
    post(:edit_species_list, params)
    assert_response(:action => :show_species_list)
    assert_equal(10 + v_obs, spl.user.reload.contribution)
    assert_equal(sp_count + 1, spl.reload.observations.size)
    assert(!spl.name_included(name))
    assert(spl.name_included(approved_name))
  end

  # ----------------------------
  #  Upload files.
  # ----------------------------

  def test_upload_species_list
    spl = species_lists(:first_species_list)
    params = {
      :id => spl.id
    }
    requires_user(:upload_species_list, :show_species_list, params)
    assert_form_action(:action => 'upload_species_list', :id => spl.id)
  end

  def test_read_species_list
    # TODO: Test read_species_list with a file larger than 13K to see if it
    # gets a TempFile or a StringIO.
    spl = species_lists(:first_species_list)
    assert_equal(0, spl.observations.length)
    list_data = "Agaricus bisporus\r\nBoletus rubripes\r\nAmanita phalloides"
    file = StringIOPlus.new(list_data)
    file.content_type = 'text/plain'
    params = {
      "id" => spl.id,
      "species_list" => {
        "file" => file
      }
    }
    post_requires_login(:upload_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, @rolf.reload.contribution)
    # Doesn't actually change list, just feeds it to edit_species_list
    assert_equal(list_data, @controller.instance_variable_get('@list_members'))
  end

  def test_read_species_list_two
    spl = species_lists(:first_species_list)
    assert_equal(0, spl.observations.length)
    filename = "#{RAILS_ROOT}/test/fixtures/species_lists/foray_notes.txt"
    file = File.new(filename)
    list_data = file.read.split(/\s*\n\s*/).reject(&:blank?).join("\r\n")
    file = FilePlus.new(filename)
    file.content_type = 'text/plain'
    params = {
      "id" => spl.id,
      "species_list" => {
        "file" => file
      }
    }
    post_requires_login(:upload_species_list, params)
    assert_response('edit_species_list')
    assert_equal(10, @rolf.reload.contribution)
    # Doesn't preserve order yet.  Have to resort in order to compare.
    # assert_equal(list_data, @controller.instance_variable_get('@list_members'))
    new_data = @controller.instance_variable_get('@list_members')
    new_data = new_data.split("\r\n").sort.join("\r\n")
    assert_equal(list_data, new_data)
  end

  # ----------------------------
  #  Name lister and reports.
  # ----------------------------

  def test_make_report
    now = Time.now

    User.current = @rolf
    tapinella = Name.create(
      :author      => '(Batsch) Šutara',
      :text_name   => 'Tapinella atrotomentosa',
      :search_name => 'Tapinella atrotomentosa (Batsch) Šutara',
      :deprecated  => false,
      :rank        => :Species
    )

    list = species_lists(:first_species_list)
    args = {
      :place_name    => 'limbo',
      :when     => now,
      :created  => now,
      :modified => now,
      :user     => @rolf,
      :specimen => false,
    }
    list.construct_observation(args.merge(:what => tapinella))
    list.construct_observation(args.merge(:what => names(:fungi)))
    list.construct_observation(args.merge(:what => names(:coprinus_comatus)))
    list.construct_observation(args.merge(:what => names(:lactarius_alpigenes)))
    list.save # just in case

    get(:make_report, :id => list.id, :type => 'txt')
    path = "#{RAILS_ROOT}/test/fixtures/reports"
    assert_response_equal_file("#{path}/test.txt")

    get(:make_report, :id => list.id, :type => 'rtf')
    assert_response_equal_file("#{path}/test.rtf") do |x|
      x.sub(/\{\\createim\\yr.*\}/, '')
    end

    get(:make_report, :id => list.id, :type => 'csv')
    assert_response_equal_file("#{path}/test.csv")
  end

  def test_name_lister
    # This will have to be very rudimentary, since the vast majority of the
    # complexity is in Javascript.  Sigh.
    get(:name_lister)

    params = {
      :results => [
        'Amanita baccata|sensu Borealis*',
        'Coprinus comatus*',
        'Fungi*',
        'Lactarius alpigenes'
      ].join("\n")
    }

    @request.session[:user_id] = 1
    post(:name_lister, params.merge(:commit => :name_lister_submit_spl.l))
    ids = @controller.instance_variable_get('@objs').map {|n| n.id}
    assert_equal([6, 2, 1, 14], ids)
    assert_response('create_species_list')

    @request.session[:user_id] = nil
    post(:name_lister, params.merge(:commit => :name_lister_submit_txt.l))
    path = "#{RAILS_ROOT}/test/fixtures/reports"
    assert_response_equal_file("#{path}/test2.txt")

    @request.session[:user_id] = nil
    post(:name_lister, params.merge(:commit => :name_lister_submit_rtf.l))
    path = "#{RAILS_ROOT}/test/fixtures/reports"
    assert_response_equal_file("#{path}/test2.rtf") do |x|
      x.sub(/\{\\createim\\yr.*\}/, '')
    end

    @request.session[:user_id] = nil
    post(:name_lister, params.merge(:commit => :name_lister_submit_csv.l))
    assert_response_equal_file("#{path}/test2.csv")
  end

  def test_name_resolution
    params = {
      :species_list => {
        :when  => Time.now,
        :place_name => 'Somewhere, California, USA',
        :title => 'title',
        :notes => 'notes',
      },
      :member => { :notes => "" },
      :list => {},
    }
    @request.session[:user_id] = 1

    params[:list][:members] = [
      'Fungi',
      'Agaricus sp',
      'Psalliota sp.',
      '"One"',
      '"Two" sp',
      '"Three" sp.',
      'Agaricus "blah"',
      'Chlorophyllum Author',
      'Lepiota sp Author',
    ].join("\n")
    params[:approved_names] = [
      'Psalliota sp.',
      '"One"',
      '"Two" sp',
      '"Three" sp.',
      'Agaricus "blah"',
      'Chlorophyllum Author',
      'Lepiota sp Author',
    ].join("\r\n")
    post(:create_species_list, params)
    assert_response(:controller => :location, :action => :create_location)
    assert_equal([
      'Fungi sp.',
      'Agaricus sp.',
      'Psalliota sp.',
      'Chlorophyllum sp. Author',
      'Lepiota sp. Author',
      '"One" sp.',
      '"Two" sp.',
      '"Three" sp.',
      'Agaricus "blah"',
    ].sort, assigns(:species_list).observations.map {|x| x.name.search_name}. sort)

    params[:list][:members] = [
      'Fungi',
      'Agaricus sp',
      'Psalliota sp.',
      '"One"',
      '"Two" sp',
      '"Three" sp.',
      'Agaricus "blah"',
      'Chlorophyllum Author',
      'Lepiota sp Author',
      'Lepiota sp. Author',
    ].join("\n")
    params[:approved_names] = [
      'Psalliota sp.',
    ].join("\r\n")
    post(:create_species_list, params)
    assert_response(:controller => :location, :action => :create_location)
    assert_equal([
      'Fungi sp.',
      'Agaricus sp.',
      'Psalliota sp.',
      'Chlorophyllum sp. Author',
      'Lepiota sp. Author',
      'Lepiota sp. Author',
      '"One" sp.',
      '"Two" sp.',
      '"Three" sp.',
      'Agaricus "blah"',
    ].sort, assigns(:species_list).observations.map {|x| x.name.search_name}.sort)
  end

  # ----------------------------
  #  Bulk observation editor.
  # ----------------------------

  def test_bulk_editor
    now = Time.now

    obs1 = observations(:minimal_unknown)
    obs2 = observations(:detailed_unknown)
    obs3 = observations(:coprinus_comatus_obs)
    old_vote1 = obs1.namings.first.users_vote(obs1.user).value rescue nil
    old_vote2 = obs2.namings.first.users_vote(obs2.user).value rescue nil
    old_vote3 = obs3.namings.first.users_vote(obs3.user).value rescue nil

    spl = species_lists(:unknown_species_list)
    spl.observations << obs3
    spl.reload

    assert_equal([obs1, obs2, obs3], spl.observations)
    assert_equal(@mary, spl.user)
    assert_equal(@mary, obs1.user)
    assert_equal(@mary, obs2.user)
    assert_equal(@rolf, obs3.user)

    params = { :id => spl.id }
    login('dick')
    get(:bulk_editor, params)
    assert_response(:action => :show_species_list)

    login('mary')
    get(:bulk_editor, params)
    assert_response('bulk_editor')

    # # No changes.
    # params = {
    #   :id => spl.id,
    #   :observation => {
    #     obs1.id.to_s => obs1.attributes.merge(
    #       :place_name => (obs1.location.name rescue obs1.where),
    #       :vote       => old_vote1,
    #     ),
    #     obs2.id.to_s => obs2.attributes.merge(
    #       :place_name => (obs2.location.name rescue obs2.where),
    #       :vote       => old_vote2,
    #     )
    #   },
    # }
    # post_requires_user(:bulk_editor, :show_species_list, params, 'mary')
    # assert_response(:show_species_list, :id => spl.id)
    # assert_flash_warning
    # for old_obs, old_vote in [ [obs1,old_vote1], [obs2,old_vote2], [obs3,old_vote3] ]
    #   new_obs = Observation.find(old_obs.id)
    #   assert_equal(old_vote, new_obs.namings.first.users_vote(new_obs.user).value rescue nil)
    #   assert_equal(old_obs.when,                   new_obs.when)
    #   assert_equal(old_obs.where,                  new_obs.where)
    #   assert_equal(old_obs.location_id             new_obs.location_id)
    #   assert_equal(old_obs.notes,                  new_obs.notes)
    #   assert_equal(old_obs.lat,                    new_obs.lat)
    #   assert_equal(old_obs.long,                   new_obs.long)
    #   assert_equal(old_obs.alt,                    new_obs.alt)
    #   assert_equal(old_obs.is_collection_location, new_obs.is_collection_location)
    #   assert_equal(old_obs.specimen,               new_obs.specimen)
    # end
    #
    # # Make legal changes.
    # params = {
    #   :id => spl.id,
    #   :observation => {
    #     obs1.id.to_s => obs1.attributes.merge(
    #       :when       => now,
    #       :place_name => 'new location',
    #       :notes      => 'new notes',
    #       :vote       => Vote.minimum_vote,
    #     ),
    #     obs2.id.to_s => obs2.attributes.merge(
    #       :place_name => (obs2.location.name rescue obs2.where),
    #       :lat      => '12 34 56 N',
    #       :long     => '78 9 12 W',
    #       :alt      => '345 ft',
    #       :is_collection_location => '1',
    #       :specimen => '0',
    #     ),
    #   },
    # }
    # login('mary')
    # post(:bulk_editor, params)
    # assert_response(:show_species_list, :id => spl.id)
    # assert_flash_success
    # obs1_new = Observation.find(obs1.id)
    # obs2_new = Observation.find(obs2.id)
    # new_vote1 = obs1_new.namings.first.users_vote(obs1.user).value rescue nil
    # new_vote2 = obs2_new.namings.first.users_vote(obs2.user).value rescue nil
    # assert_not_equal(Vote.minimum_vote, old_vote1)
    # assert_equal(Vote.minimum_vote, new_vote1)
    # assert_equal(now,            new_obs1.when)
    # assert_equal('new location', new_obs1.where)
    # assert_equal(nil,            new_obs1.location)
    # assert_equal('new notes',    new_obs1.notes)
    # assert_equal(obs1.lat,       new_obs1.lat)
    # assert_equal(obs1.long,      new_obs1.long)
    # assert_equal(obs1.alt,       new_obs1.alt)
    # assert_equal(obs1.is_collection_location, new_obs1.is_collection_location)
    # assert_equal(obs1.specimen,  new_obs1.specimen)
    # assert_equal(old_vote2, new_vote2)
    # assert_equal(obs2.when,        new_obs2.when)
    # assert_equal(obs2.where,       new_obs2.where)
    # assert_equal(obs2.location_id, new_obs2.location_id)
    # assert_equal(obs2.notes,       new_obs2.notes)
    # assert_equal(12.5822,          new_obs2.lat)
    # assert_equal(-78.1533,         new_obs2.long)
    # assert_equal(105,              new_obs2.alt)
    # assert_equal(true,             new_obs2.is_collection_location)
    # assert_equal(true,             new_obs2.specimen)
    #
    # # Make illegal change.
    # params = {
    #   :id => spl.id,
    #   :observation => {
    #     obs3.id.to_s => obs3.attributes.merge(
    #       :place_name => (obs3.location.name rescue obs3.where),
    #       :vote       => old_vote3,
    #       :notes      => 'new notes',
    #     ),
    #   },
    # }
    # login('mary')
    # post(:bulk_editor, params)
    # assert_response(:show_species_list, :id => spl.id)
    # assert_flash_error
    # new_obs3 = Observation.find(obs3.id)
    # assert_equal(old_vote3, new_obs3.namings.first.users_vote(obs3.user).value rescue nil)
    # assert_equal(obs3.when,                   new_obs3.when)
    # assert_equal(obs3.where,                  new_obs3.where)
    # assert_equal(obs3.location_id             new_obs3.location_id)
    # assert_equal(obs3.notes,                  new_obs3.notes)
    # assert_equal(obs3.lat,                    new_obs3.lat)
    # assert_equal(obs3.long,                   new_obs3.long)
    # assert_equal(obs3.alt,                    new_obs3.alt)
    # assert_equal(obs3.is_collection_location, new_obs3.is_collection_location)
    # assert_equal(obs3.specimen,               new_obs3.specimen)
    #
    # # But let Rolf edit his own observations in someone else's list(?)
    # params = {
    #   :id => spl.id,
    #   :observation => {
    #     obs3.id.to_s => obs3.attributes.merge(
    #       :place_name => (obs3.location.name rescue obs3.where),
    #       :vote       => old_vote3,
    #       :notes      => 'new notes',
    #     ),
    #   },
    # }
    # login('rolf')
    # post(:bulk_editor, params)
    # assert_response(:show_species_list, :id => spl.id)
    # assert_flash_success
    # new_obs3 = Observation.find(obs3.id)
    # assert_equal('new notes', new_obs3.notes)
  end
end
