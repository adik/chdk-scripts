--[[   Dark Frame Shooter for Meteors

@title Meteor v2.7
@chdk_version 1.3
  2010/11/16 original script by fudgey
  2012/10/18 modified by waterwingz to shoot continuously and record dark frame periodically
  2013/12/23 update to support early DryOS cameras by srsa_4c
  2014/03/27 modified by waterwingz with additional parameters and to remove the nasty tv96 conversion hack

@param     t Tv exposure (secs)
 @default  t 25
 @range    t 1 3600
@param     e ISO
  @default e 2
  @values  e None 80 100 200 400 800 1250 1600 3200 6400
@param     a Av (f-stop)
  @default a 4
  @values  a 1.8 2.0 2.2 2.6 2.8 3.2 3.5 4.0 4.5 5.0 5.6 6.3 7.1 8.0
@param     x ND filter
  @default x 0
  @values  x Out In
@param     n Total shots (0=infinite)
 @default  n 0
 @range    n 0  100000
@param     i Shot Interval (secs)
 @default  i 1
 @range    i 1 3600
@param    z Zoom position
  @default z 0
  @values  z Off 0% 10% 20% 30% 40% 50% 60% 70% 80% 90% 100%
@param     r Enable Raw
 @default  r 0
 @range    r 0 1
@param     f Focus @ Infinity Mode
  @default f 0
  @values  f None AFL MF
@param     d Dark Frame Mode
 @default  d 2
 @values   d None Canon CHDK
@param     s Shots per Dark Frame
 @default  s 50
 @range    s 0 1000
@param     b Display Off?
 @default  b 0
 @range    b 0 1

--]]

props=require("propcase")

    chdk_version=100
    build = 0
    interval = i*1000

-- Register shutter control event procs depending on os and define functions
-- openshutter() and closeshutter() to control mechanical shutter.
function init()

   set_console_layout(1, 0, 45, 14)

   local bi=get_buildinfo()
   chdk_version= tonumber(string.sub(bi.build_number,1,1))*100 + tonumber(string.sub(bi.build_number,3,3))*10 + tonumber(string.sub(bi.build_number,5,5))
   if ( tonumber(bi.build_revision) > 0 ) then
       build = tonumber(bi.build_revision)
   else
       build = tonumber(string.match(bi.build_number,'-(%d+)$'))
   end
   if ((chdk_version<120) or ((chdk_version==120)and(build<3276)) or ((chdk_version==130)and(build<3383))) then
       error("CHDK 1.2.0 build 3276 or higher required")
   end

  -- check for native call interface:
  if (type(call_event_proc) ~= "function" ) then
    error("Error: CHDK native calls not enabled")
  end

  if bi.os=="vxworks" then
    closeproc="CloseMShutter"
    openproc="OpenMShutter"
    if (call_event_proc("InitializeAdjustmentFunction") == -1) then
      error("InitAdjFunc failed")
    end
  elseif bi.os=="dryos" then
    closeproc="CloseMechaShutter"
    openproc="OpenMechaShutter"
    if (call_event_proc("Mecha.Create") == -1) then
      if (call_event_proc("MechaRegisterEventProcedure") == -1) then
        error("Mecha.Create failed")
      end    
    end
  else
    error("Unknown OS:" .. bi.os)
  end

  -- close mechanical shutter
  function closeshutter()
    if (call_event_proc(closeproc) == -1) then
      print("closeshutter failed")
    end
  end

  -- open mechanical shutter
  function openshutter()
    if (call_event_proc(openproc) == -1) then
      print("openshutter failed")
    end
  end

  -- switch to record mode if necessary
  if ( get_mode() == false ) then
    print("switching to record mode")
    sleep(1000)
    set_record(1)
    while ( get_mode() == false) do
      sleep(100)
    end
  end

  -- test for still photo in record mode
  rec,vid=get_mode()
  if rec ~= true then
    error("Not in REC mode")
  elseif vid == true then
    error("Video not supported")
  end

  -- make sure we are in P mode
  capmode=require("capmode")
  if ( capmode.get_name() ~= "P") then
     print("Not in Program mode!")
  end

  -- check that flash is disabled
  if ( get_flash_mode() ~= 2) then
      error("Flash not disabled!")
  end

 -- turn seconds into tv96 values and get sv and av setpoints
  tv96 =seconds_to_tv96(t,1)
  local sv_table = { 381, 411, 507, 603, 699, 761, 795, 891, 987 }
  if ( e > 0 ) then sv96 = sv_table[e] else sv96=nil end
  local av_table = { 171, 192, 218, 265, 285, 322, 347, 384, 417, 446, 477, 510, 543, 576 }
  av96 = av_table[a+1]

 -- zoom position
    if ( z>0 ) then
        update_zoom((z-1)*10)
    end

 -- lock focus if enabled
    lock_focus()

 -- disable display
    if ( b==1 ) then set_lcd_display(0) end

end -- init()


function format_tv(val)
    if ( val == nil ) then return("-") end
    return tv96_to_usec(val)/1000000
end

function format_av(val)
    if ( val == nil ) then return("-") end
    local fstop=av96_to_aperture(val)+50
    return((fstop/1000).."."..(fstop%1000)/100)
end

function format_sv(val)
    if ( val == nil ) then return("-") end
    return( ((iso_real_to_market(sv96_to_iso(val))+5)/10)*10 )
end

-- focus lock and unlock
function lock_focus()
    if (f > 0) then                                            -- focus mode requested ?
        if     ( f == 1 ) then                                 -- method 1 :  set_aflock() command enables MF
            if (chdk_version==120) then
                set_aflock(1)
                set_prop(props.AF_LOCK,1)
            else
                set_aflock(1)
            end
            if (get_prop(props.AF_LOCK) == 1) then print(" AFL enabled") else print(" AFL failed ***") end
        else                                                            -- mf mode requested
            if (chdk_version==120) then                                 -- CHDK 1.2.0 : call event proc or levents to try and enable MF mode
                if call_event_proc("SS.Create") ~= -1 then
                    if call_event_proc("SS.MFOn") == -1 then
                            call_event_proc("PT_MFOn")
                    end
                elseif call_event_proc("RegisterShootSeqEvent") ~= -1 then
                    if call_event_proc("PT_MFOn") == -1 then
                        call_event_proc("MFOn")
                    end
                end
                if (get_prop(props.FOCUS_MODE) == 0 ) then              -- MF not set - try levent PressSw1AndMF
                    post_levent_for_npt("PressSw1AndMF")
                    sleep(500)
                end
            elseif (chdk_version >= 130) then                           -- CHDK 1.3.0 : set_mf()
                if ( set_mf(1) == 0 ) then set_aflock(1) end            --    as a fall back, try setting AFL is set_mf fails
            end
            if (get_prop(props.FOCUS_MODE) == 1) then print(" MF enabled") else print(" MF enable failed ***") end
        end
        sleep(1000)
        if(set_focus(50000)==0) then print("infinity focus error") end
        sleep(2000)
    end
end

function unlock_focus()
    if (f > 0) then                                            -- focus mode requested ?
        if (f == 1 ) then                                      -- method 1 : AFL
            if (chdk_version==120) then
                set_aflock(0)
                set_prop(props.AF_LOCK,0)
            else
                set_aflock(0)
            end
            if (get_prop(props.AF_LOCK) == 0) then print("AFL unlocked") else print("AFL unlock failed") end
         else                                                           -- mf mode requested
             if (chdk_version==120) then                                -- CHDK 1.2.0 : call event proc or levents to try and enable MF mode
                if call_event_proc("SS.Create") ~= -1 then
                    if call_event_proc("SS.MFOff") == -1 then
                        call_event_proc("PT_MFOff")
                    end
                elseif call_event_proc("RegisterShootSeqEvent") ~= -1 then
                    if call_event_proc("PT_MFOff") == -1 then
                        call_event_proc("MFOff")
                    end
                end
                if (get_prop(props.FOCUS_MODE) == 1 ) then              -- MF not reset - try levent PressSw1AndMF
                    post_levent_for_npt("PressSw1AndMF")
                    sleep(500)
                end
            elseif (chdk_version >= 130) then                           -- CHDK 1.3.0 : set_mf()
                if ( set_mf(0) == 0 ) then set_aflock(0) end            --    fall back so reset AFL is set_mf fails
            end
            if (get_prop(props.FOCUS_MODE) == 0) then print("MF disabled") else print("MF disable failed") end
        end
        sleep(100)
    end
end

-- zoom position
function update_zoom(zpos)
    if(zpos ~= nil) then
        zstep=((get_zoom_steps()-1)*zpos)/100
        print(" setting zoom to "..zpos.."%, step="..zstep)
        sleep(200)
        set_zoom(zstep)
        sleep(2000)
    end
end

--[[
     Exposure parameter controlled shoot: if argument dark==false shoots a real photo.
     If dark==true, function shoots a dark frame.
--]]
function expcontrol_shoot(dark)
    if( sv96 ~= nil ) then set_sv96(sv96) end
    set_av96_direct(av96)
    set_tv96_direct(tv96)
    if(x == 1) then                      -- ND filter requested ?
        set_nd_filter(1)                 -- activate the ND filter
    else
        set_nd_filter(2)                 -- deactiveate the ND filter
    end
    press("shoot_half")                  -- half shoot and wait for auto exposure
    repeat
    sleep(10)
    until get_shooting() == true
    if dark == true then                 -- if dark frame
    closeshutter()                       -- close shutter
    sleep(200)                           -- wait for shutter to close (don't know if this is required)
    end
    press("shoot_full")                  -- take the photo
    sleep(50)
    release("shoot_full_only")
    sleep(50)
    release("shoot_half")
    repeat
    sleep(20)
    until get_shooting() ~= true
end

-- restore user raw mode and dark frame reduction settings:
function restore()
   set_raw(rawmode)
   set_raw_nr(dfrmode)
   if ( b==1 ) then set_lcd_display(1) end
   unlock_focus()
end

-- store user raw mode and dark frame reduction settings
rawmode=get_raw()
dfrmode=get_raw_nr()

-- script starts here
init()

set_raw(r)                       -- enable RAW or DNG ?
if(d~=1) then set_raw_nr(1) end  -- disable Canon's dark frame reduction ?

df_count=s
if (n==0) then n=30000 end
shot_count = 1
next_shot_time = get_tick_count()

repeat
    if( next_shot_time <= get_tick_count() ) then
        next_shot_time = get_tick_count() + interval
        expcontrol_shoot(false)        -- shoot a photo, store its exposure params
        shot_focus= get_focus()
        if(shot_focus ~= -1) and (shot_focus < 20000) then
            focus_string=" foc:"..(shot_focus/1000).."."..(((shot_focus%1000)+50)/100).."m"
        else focus_string=" foc:infinity" end
        print("shot:"..shot_count.." tv:"..format_tv(tv96)," ISO:"..format_sv(sv96),"av:f"..format_av(av96)..focus_string)
        if (d==2) then
            df_count=df_count+1
            if (df_count >= s) then
                df_count=0
                print("shot : dark frame")
                expcontrol_shoot(true) -- shoot dark frame using stored exposure parameters
            end
        end
        shot_count=shot_count+1
    end
    wait_click(100)
until ( shot_count > n ) or is_key("menu")

if (d==2) then
   print("shot : final dark frame")
   expcontrol_shoot(true)
end

restore()
print("done")
