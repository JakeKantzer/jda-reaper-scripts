--[[
 * ReaScript Name: Realtime render MIDI items within time selection dry, ignoring first effect
 * About: Meant to be used with tracks using ReaInsert with a hardware synthesizer. Bypasses all but first effect (ReaInsert), renders the items within the time selection to a new track, copies all but the first effect to the new track, restores the bypass states of the effects on the original track, and mutes the original MIDI item(s).
 * Instructions: Select a track using ReaInsert in the first FX slot for an instrument and set the time selection to one containing MIDI items on that track.
 * Author: Jake D'Arc
 * Author URI: https://linktr.ee/arclighthalo
 * Repository: 
 * Repository URI: 
 * Licence: MIT
 * Forum Thread: 
 * Forum Thread URI: 
 * REAPER: 7.21
 * Version: 1.0
--]]

--[[
 * Changelog:
 * v1.0 ( 2024-08-25 )
  + Initial Release
--]]

function bounce(second_pass)
  -- Render to new track
  if second_pass then
    reaper.Main_OnCommand(42416, 0)
  else
    reaper.Main_OnCommand(41719, 0)
  end
end

function main(second_pass)
  -- Only continue if exactly one track is selected
  local track_count = reaper.CountSelectedTracks(0)
  if track_count ~= 1 then 
    reaper.ShowMessageBox("Please select a single track.", "Error", 0)  
  return end

  -- Check that there's a loop
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if start_time == end_time then
    reaper.ShowMessageBox("There is no loop set, aborting.", "Error", 0)
  return end

  reaper.Undo_BeginBlock()

  -- Get the selected track
  local orig_track = reaper.GetSelectedTrack(0, 0)

  -- Cut early if first effect isn't ReaInsert
  local first_fx, first_fx_name = reaper.TrackFX_GetFXName(orig_track, 0)
  if not first_fx or first_fx_name ~= "VST: ReaInsert (Cockos)" then
    reaper.ShowMessageBox("The first effect on this track is not ReaInsert, aborting.", "Error", 0)
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

      -- If one of the items isn't MIDI, bail because we have no idea what's going on
      local take = reaper.GetActiveTake(selected_items[i+1])
      if take == nil or not reaper.TakeIsMIDI(take) then
        reaper.ShowMessageBox("One or more of the selected items is not MIDI, aborting.", "Error", 0)
      return end
  end

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

  -- Function to restore the bypass state of all FX in a track
  function restore_bypass_state(track, fx_bypass_states)
    for i, state in pairs(fx_bypass_states) do
      reaper.TrackFX_SetEnabled(track, i, state)
    end
  end

  -- Render to new track
  bounce(second_pass)

  -- Restore the previous render speed
  recall_render_speed_id = reaper.NamedCommandLookup("_XENAKIOS_RECALLRENDERSPEED")
  if recall_render_speed_id == nil then return end
  reaper.Main_OnCommand(recall_render_speed_id, 0)

  local new_track = reaper.GetSelectedTrack(0, 0)

  -- Get the number of FX in the source track
  local num_fx = reaper.TrackFX_GetCount(orig_track)

  -- Restore the original bypass states before copying effects
  for i, state in pairs(fx_bypass_states) do
      reaper.TrackFX_SetEnabled(orig_track, i, state)
  end

  -- Copy all FX except for the first one
  for i = 1, num_fx - 1 do
      local fx_chunk = reaper.TrackFX_GetFXGUID(orig_track, i)
      reaper.TrackFX_CopyToTrack(orig_track, i, new_track, reaper.TrackFX_GetCount(new_track), false)
  end

  -- Unmute the original track
  reaper.SetMediaTrackInfo_Value(orig_track, "B_MUTE", 0)

  -- Mute the items on the original track
  for i = 1, #selected_items do
      reaper.SetMediaItemInfo_Value(selected_items[i], "B_MUTE", 1)
  end

  reaper.Undo_EndBlock('Realtime render MIDI items within time selection dry, ignoring first effect',-1)

  -- Update the arrange view to reflect the changes
  reaper.UpdateArrange()
end

return main