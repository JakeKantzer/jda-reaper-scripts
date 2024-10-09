--[[
  @author Jake d'Arc
  @license MIT
  @version 1.0.0
  @about Add sends from selected track(s) to tracks with names starting with "FX: "
  @changelog
    - init
  @provides
    [main] JDA_Add_Sends_to_Named.lua
]]

function main()
  -- Don't do anything if no tracks are selected
  local selected_track_count = reaper.CountSelectedTracks(0)
  if selected_track_count == 0 then return end

  reaper.Undo_BeginBlock()

  -- Store the currently selected tracks
  local selected_tracks = {}
  for i = 0, selected_track_count - 1 do
      selected_tracks[i] = reaper.GetSelectedTrack(0, i)
  end

  -- Find tracks starting with "FX: " and add sends to them from the selected tracks
  local track_count = reaper.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    local retval, track_name = reaper.GetTrackName(track)
    if string.sub(track_name, 0, 4) == "FX: " then
      for j = 0, selected_track_count - 1 do
        local start_track = reaper.GetSelectedTrack(0, j)

        local duplicate_send = false;
        local send_count = reaper.GetTrackNumSends(start_track, 0)
        for k = 0, send_count - 1 do
          local retval, send_name = reaper.GetTrackSendName(start_track, k)
          if send_name == track_name then 
            duplicate_send = true
            break
          end
        end

        if duplicate_send then goto continue end

        local new_send = reaper.CreateTrackSend(start_track, track)
        reaper.SetTrackSendUIVol(start_track, new_send, 0, -1)

        ::continue::
      end
    end
  end

  -- Update the arrange view to reflect the changes
  reaper.UpdateArrange()

  reaper.Undo_EndBlock('Add Sends to Named',-1)
end

main()