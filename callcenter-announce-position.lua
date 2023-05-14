function getAudioLength(filepath)
    local command = string.format('ffprobe -i "%s" -show_entries format=duration -v quiet -of csv="p=0"', filepath)
    local handle = io.popen(command)
    local duration = handle:read("*a")
    handle:close()

    -- Convert the duration from string to a number
    local length = tonumber(duration) * 1000
    return length
end



api = freeswitch.API()
caller_uuid = argv[1]
caller_id = tostring(argv[4])
queue_name = argv[2]
mseconds = argv[3]
if caller_uuid == nil or queue_name == nil or mseconds == nil then
    return
end

played_greeting = false  -- Flag to keep track of whether the greeting has been played
freeswitch.msleep(100)
while (true) do
    members = api:executeString("callcenter_config queue list members "..queue_name)
    pos = 1
    exists = false
    for line in members:gmatch("[^\r\n]+") do
        if (string.find(line, "Trying") ~= nil or string.find(line, "Waiting") ~= nil) then
            -- Members have a position when their state is Waiting or Trying
            if string.find(line, caller_uuid, 1, true) ~= nil then
                -- Member still in queue, so script must continue
                exists = true
                if played_greeting then
                    api:executeString("uuid_audio "..caller_uuid.." start write level -4") -- Decrease the volume to -4
                    api:executeString("uuid_displace "..caller_uuid.." start ivr/ivr-you_are_number.wav 0 mux")
                    freeswitch.msleep(getAudioLength("/usr/share/freeswitch/sounds/en/us/callie/ivr/48000/ivr-you_are_number.wav"))
                    api:executeString("uuid_displace "..caller_uuid.." start digits/"..pos..".wav 0 mux")
                    freeswitch.msleep(getAudioLength("/usr/share/freeswitch/sounds/en/us/callie/digits/48000/"..pos..".wav"))
                    api:executeString("uuid_displace "..caller_uuid.." start ivr/inWarteschleife.mp3.wav 0 mux")
                    freeswitch.msleep(getAudioLength("/usr/share/freeswitch/sounds/en/us/callie/ivr/48000/inWarteschleife.mp3.wav"))
                    api:executeString("uuid_audio "..caller_uuid.." stop write level 0") -- Unmute the channel
                end
                if not played_greeting then  -- Play greeting if it hasn't been played yet
                    api:executeString("uuid_audio "..caller_uuid.." start write level -4") -- Decrease the volume to -4
                    api:executeString("uuid_displace "..caller_uuid.." start ivr/Begrüßung.wav 0 mux")
                    freeswitch.msleep(getAudioLength("/usr/share/freeswitch/sounds/en/us/callie/ivr/48000/Begrüßung.wav"))
                    api:executeString("uuid_audio "..caller_uuid.." start write level 0") -- Decrease the volume to -4
                    played_greeting = true
                end
            end
            pos = pos + 1
        end
    end
    -- If member was not found in queue, or its status is Aborted - terminate script
    if exists == false then
        return
    end
    -- Pause between announcements, except for the first iteration
    if played_greeting then
        freeswitch.msleep(mseconds)
    end
end
