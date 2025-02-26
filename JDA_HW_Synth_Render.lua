--[[
  @author Jake d'Arc
  @license MIT
  @version 1.0.0
  @about Automatic real-time bouncing and FX chain copying for tracks using ReaInsert with synths
  @changelog
    - init
  @provides
    [main] JDA_HW_Synth_Render/JDA_HW_Synth_Render_1P.lua
    [main] JDA_HW_Synth_Render/JDA_HW_Synth_Render_2P.lua
]]

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

function bounce(second_pass)
  -- Render to new track
  if second_pass then
    reaper.Main_OnCommand(42416, 0)
  else
    reaper.Main_OnCommand(41719, 0)
  end
end

function main(second_pass)
  reaper.Undo_BeginBlock()

  -- If we didn't end up with a track, check if one is selected already, otherwise bail
  local selected_track_count = reaper.CountSelectedTracks(0)
  if selected_track_count > 1 then
    reaper.ShowMessageBox("Please select a single track.", "Error", 0)
  return end

  local orig_track = reaper.GetSelectedTrack(0, 0)
  if orig_track == nil then
    reaper.ShowMessageBox("Please select a track.", "Error", 0)
  return end

  -- Deselect all items first
  reaper.Main_OnCommand(40289, 0)

  -- Select all items on selected tracks in current time selection
  reaper.Main_OnCommand(40718, 0)

  -- Store the currently selected items
  local selected_items = {}
  local num_selected_items = reaper.CountSelectedMediaItems(0)
  for i = 0, num_selected_items - 1 do
      selected_items[i+1] = reaper.GetSelectedMediaItem(0, i)
  end

  -- Check that there's a loop
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if start_time == end_time then
    reaper.ShowMessageBox("There is no loop set, aborting.", "Error", 0)
  return end

  -- Cut early if first effect isn't ReaInsert
  local first_fx, first_fx_name = reaper.TrackFX_GetFXName(orig_track, 0)
  if not first_fx or first_fx_name ~= "VST: ReaInsert (Cockos)" then
    reaper.ShowMessageBox("The first effect on this track is not ReaInsert, aborting.", "Error", 0)
  return end

  -- Get the automation mode, store it, and set it to trim/read so effects bypass correctly
  local orig_automation_mode = reaper.GetTrackAutomationMode(orig_track)
  reaper.SetTrackAutomationMode(orig_track, 0)

  -- Store the original render speed
  store_render_speed_id = reaper.NamedCommandLookup("_XENAKIOS_STORERENDERSPEED")
  if store_render_speed_id == nil then
    reaper.ShowMessageBox("Please install SWS!", "Error", 0) -- If SWS isn't installed, it'll blow up here
  return end
  reaper.Main_OnCommand(store_render_speed_id, 0)

  -- Set the render speed to realtime
  set_render_speed_rt_id = reaper.NamedCommandLookup("_XENAKIOS_SETRENDERSPEEDRT")
  if set_render_speed_rt_id == nil then return end
  reaper.Main_OnCommand(set_render_speed_rt_id, 0)

  -- Store the original bypass states and bypass all but the first effect
  local fx_bypass_states = {}
  local num_fx = reaper.TrackFX_GetCount(orig_track)
  for i = 0, num_fx - 1 do
      fx_bypass_states[i] = reaper.TrackFX_GetEnabled(orig_track, i)
      if i ~= 0 then reaper.TrackFX_SetEnabled(orig_track, i, false) end
  end

  -- Render to new track
  bounce(second_pass)

  -- Restore the previous render speed
  recall_render_speed_id = reaper.NamedCommandLookup("_XENAKIOS_RECALLRENDERSPEED")
  if recall_render_speed_id == nil then return end
  reaper.Main_OnCommand(recall_render_speed_id, 0)

  -- Assign the new track to a variable for later
  local new_track = reaper.GetSelectedTrack(0, 0)

  -- Get the number of FX in the source track
  local num_fx = reaper.TrackFX_GetCount(orig_track)

  -- Restore the original bypass states before copying effects
  for i, state in pairs(fx_bypass_states) do
      reaper.TrackFX_SetEnabled(orig_track, i, state)
  end
  
  -- Get FX chunk from original track and send to new track (ultraschall needed for envelopes)
  local orig_tsc_returned, orig_track_state_chunk = reaper.GetTrackStateChunk(orig_track, "", false)
  local new_tsc_returned, new_track_state_chunk = reaper.GetTrackStateChunk(new_track, "", false)
  local orig_track_fxsc = ultraschall.GetFXStateChunk(orig_track_state_chunk)
  local new_fxsc_returned, new_modified_track_state_chunk = ultraschall.SetFXStateChunk(new_track_state_chunk, orig_track_fxsc)
  reaper.SetTrackStateChunk(new_track, new_modified_track_state_chunk, false)

  -- Delete ReaInsert
  reaper.TrackFX_Delete(new_track, 0)

  -- Unmute the original track
  reaper.SetMediaTrackInfo_Value(orig_track, "B_MUTE", 0)

  -- Restore the original automation mode
  reaper.SetTrackAutomationMode(orig_track, orig_automation_mode)

  -- Mute the items on the original track
  for i = 1, #selected_items do
      reaper.SetMediaItemInfo_Value(selected_items[i], "B_MUTE", 1)
  end

  -- Update the arrange view to reflect the changes
  reaper.UpdateArrange()

  reaper.Undo_EndBlock('Hardware synth render',-1)
end

return main