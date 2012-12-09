class SpecimenController < ApplicationController
  before_filter :login_required, :except => [
    :show_specimen,
    :herbarium_index,
    :observation_index,
  ]
  
  def show_specimen  # :nologin:
    store_location
    @specimen = Specimen.find(params[:id])
    @layout = calc_layout_params
  end

  def herbarium_index # :nologin:
    store_location
    herbarium = Herbarium.find(params[:id])
    @specimens = herbarium ? herbarium.specimens : []
    @subject = herbarium.name
    if !calc_specimen_index_redirect(@specimens)
      flash_warning(:herbarium_index_no_specimens.t)
      redirect_to(:controller => 'herbarium', :action => 'show_herbarium', :id => params[:id])
    end
  end
  
  def calc_specimen_index_redirect(specimens)
    count = specimens.count
    if count != 0
      if count == 1
        redirect_to(:action => 'show_specimen', :id => specimens[0].id)
      else
        render(:action => 'specimen_index')
      end
    end
  end

  def observation_index # :nologin:
    store_location
    observation = Observation.find(params[:id])
    @specimens = observation ? observation.specimens : []
    @subject = observation.format_name
    if !calc_specimen_index_redirect(@specimens)
      flash_warning(:observation_index_no_specimens.t)
      redirect_to(:controller => 'observer', :action => 'show_observation', :id => params[:id])
    end
  end
  
  def add_specimen
    @observation = Observation.find(params[:id])
    @layout = calc_layout_params
    if @observation
      @herbarium_label = "#{@observation.name.text_name} [#{@observation.id}]"
      @herbarium_name = @user.preferred_herbarium_name
      if request.method == :post
        if valid_specimen_params(params[:specimen])
          build_specimen(params[:specimen], @observation)
        end
      end
    end
  end
 
  def valid_specimen_params(params)
    !specimen_exists(params[:herbarium_name], params[:herbarium_label])
  end
  
  def specimen_exists(herbarium_name, herbarium_label)
    for s in Specimen.find_all_by_herbarium_label(herbarium_label)
      if s.herbarium.name == herbarium_name
        flash_error(:add_specimen_already_exists.strip_html(:name => herbarium_name, :label => herbarium_label))
        return true
      end
    end
    return false
  end
  
  def build_specimen(params, obs)
    params[:user] = @user
    new_herbarium = infer_herbarium(params)
    specimen = Specimen.new(params)
    specimen.add_observation(obs)
    specimen.save
    calc_specimen_redirect(params, new_herbarium, specimen) # Need appropriate redirect
  end
  
  def infer_herbarium(params)
    herbarium_name = params[:herbarium_name].to_s
    herbarium = Herbarium.find_by_name(herbarium_name)
    result = herbarium.nil?
    if result
      herbarium = Herbarium.new(herbarium_params(params))
      herbarium.curators.push(@user)
      herbarium.save
    end
    params[:herbarium] = herbarium
    result
  end
  
  def herbarium_params(params)
    {
      :name => params[:herbarium_name],
      :description => '',
      :email => @user.email,
      :mailing_address => "",
      :place_name => ""
    }
  end

  def calc_specimen_redirect(params, new_herbarium, specimen)
    if new_herbarium
      flash_notice(:herbarium_edit.t(:name => params[:herbarium_name]))
      redirect_to(:action => 'edit_herbarium',
                  :id => specimen.herbarium_id)
    else
      redirect_to(:controller => 'observer', :action => 'show_observation', :id => specimen.observations[0].id)
    end
  end
  
  def edit_specimen # :norobots:
    @specimen = Specimen.find(params[:id])
    if can_edit?(@specimen)
      if request.method == :post
        if ok_to_update(@specimen, params[:specimen])
          update_specimen(@specimen, params[:specimen])
        end
      end
    else
      redirect_to(:action => 'show_specimen', :id => @specimen.id)
    end
  end

  def can_edit?(specimen)
    result = specimen.can_edit?(@user)
    flash_error(:edit_specimen_cannot_edit.l) if not result
    result
  end
  
  def ok_to_update(specimen, params)
    new_label = params[:herbarium_label]
    (specimen.herbarium_label == new_label) or label_free?(specimen.herbarium, new_label)
  end
  
  def label_free?(herbarium, new_label)
    result = herbarium.label_free?(new_label)
    flash_error(:edit_herbarium_duplicate_label.l(:herbarium_label => new_label, :herbarium_name => herbarium.name)) if !result
    result
  end
  
  def update_specimen(specimen, params)
    specimen.attributes = params
    specimen.save
    redirect_to(:action => 'show_specimen', :id => specimen.id)
  end
end
