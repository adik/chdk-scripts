--[[  
Ultra Motion v1.0

Licence: GPL (c) 2013, 2014, 2015 waterwingz
thx to msl for code adapted to make dawn_and_dusk() and tv2seconds(tv)

@title UltraMD v1.0
@chdk_version 1.3

@param    a Trigger Threshold
 @default a 10
 @range   a 1 255
@param    x Trigger Delay (0.1 sec)
 @default x 5
 @range   x 0 100
@param    b Zoom Step (0=none)
 @default b 0
 @range   b 0 500
@param    w Focus @ Infinity?
 @default w 0
 @range   w 0 1
@param    c Start at dawn?
 @default c 0
 @range   c 0 1
@param    d End at dusk?
 @default d 0
 @range   d 0 1
@param    e Starting Hour (24 Hr)
 @default e 9
 @range   e 0 23
@param    f Starting Minute
 @default f 0
 @range   f 0 59
@param    g Ending Hour (24 Hr)
 @default g 17
 @range   g 0 24
@param    h Ending Minute
 @default h 0
 @range   h 0 59
@param    i Day of Week
 @default i 0
 @values  i All Mon-Fri Sat&Sun
@param    j Shoot when Tv >
 @default j 0
 @values  j Off 2sec 1sec 1/2 1/4 1/8 1/30 1/60
@param    l Days between resets
 @default l 1
 @range   l 1 365
@param    k Reset Hour (24 Hr)
 @default k 2
 @range   k 1 23
@param    v Low battery shutdown mV
 @default v 0
 @range   v 0 12000
@param    m Status LED
 @default m 0
 @values  m Off 0 1 2 3 4 5 6 7 8
@param    n Display Off mode (day)
 @default n 5
 @values  n None BKLite DispKey PlayKey ShrtCut LCD
@param    u Display Off mode (night)
 @default u 3
 @values  u None BKLite DispKey PlayKey ShrtCut LCD
@param    o Latitude
 @default o 449
@param    p Longitude
 @default p -931
@param    q UTC
 @default q -6
@param    r Pause when USB connected?
 @default r 0
 @range   r 0 1
@param    s Theme
 @default s 0
 @values  s Color Mono
@param    t Logging
 @default t 3
 @values  t Off Screen SDCard Both
--]]

require("drawings")
props=require("propcase")

-- translate user parameter into usable values & names
    speed_table =       { 9999, -96, 0, 96, 192, 288, 480, 576 }
    
    threshold =           a
    delay =               x
    zoom_setpoint =       b
    if (c==1) then dawn_mode = true else dawn_mode = false end
    if (d==1) then dusk_mode = true else dusk_mode = false end
    start_time =          e*3600 + f*60
    stop_time  =          g*3600 + h*60
    dow_mode =            i
    min_Tv =             speed_table[j+1]
    reboot_hour =        k*3600 - 600  
    reboot_timer =       l
    status_led =         m-1
    day_display_mode =   n
    latitude =           o
    longitude =          p
    utc =                q
    ptp_enable =         r
    theme =              s
    log_mode =           t
    night_display_mode = u
    low_batt_trip =      v
    focus_at_infinity =  w    


-- constants
    NIGHT=0
    DAY=1
    SHORTCUT="print"       -- edit this if using shortcut key to enter sleep mode

    dawn = start_time
    dusk = stop_time
    shooting_mode = DAY
    led_state = 0
    led_timer = 0
    shot_counter = 0
    error_mode = 0
    display_state = 1
    display_hold_timer = 0
    batt_trip_count = 0

-- motion detection function
--[[
  md_detect_motion( a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p)
        a -- columns to split picture into 
        b -- rows to split picture into 
        c -- measure mode (Y,U,V R,G,B) U=0, Y=1, V=2, R=3, G=4, B=5
        d -- timeout (mSec) 
        e -- comparison interval (msec) - less than 100 may slow down other CHDK functions
        f -- trigger threshold 
        g -- draw grid (0=no, 1=grid, 2=sensitivity readout, 3=sensitivity readout & grid)   
        h -- not used in LUA
        i -- region masking mode: 0=no regions, 1=include, 2=exclude
        j --      first column
        k --      first row
        l --      last column
        m --      last row
        n -- optional parameters  (1=shoot immediate, 8=don't release shoot_full)
        o -- pixel step
        p -- trigger delay in msec
--]]        

function detect_motion(threshold, delay)  -- note : delay is in 100 mSec increments
    local a = 5
    local b = 5
    local c = 1
    local d=  60000
    local e = 500
    local g = 3
    local h = 0
    local i = 0
    local j = 1
    local k = 1
    local l = 1
    local m = 1
    local n = 1
    local o = 2
    local p = delay*100
    local t = md_detect_motion( a, b, c, d, e, threshold, g, h, i, j, k, l, m, n, o, p)
    return t
end

-- user interface

function printf(...)
    if ( log_mode == 0) then return end
    local str=string.format(...)
    if (( log_mode == 1) or (log_mode == 3)) then print(str) end
    if ( log_mode > 1 ) then
    local logname="A/ultraMD.log"
        log=io.open(logname,"a")
        log:write(os.date(),"; ",string.format(...),"\n")
        log:close()
    end
end

function tv2seconds(tv_val)
     local i = 1
     local tv_str = {"???","64","50","40","32","25","20","16","12","10","8","6",
    "5","4","3.2","2.5","2","1.6","1.3","1.0","0.8","0.6","0.5","0.4",
    "0.3","1/4","1/5","1/6","1/8","1/10","1/13","1/15","1/20","1/25",
    "1/30","1/40","1/50","1/60","1/80","1/100","1/125","1/160","1/200",
    "1/250","1/320","1/400","1/500","1/640","1/800","1/1000","1/1250",
    "1/1600","1/2000","off"  }
     local tv_ref = {
     -576, -544, -512, -480, -448, -416, -384, -352, -320, -288, -256, -224, -192, -160, -128, -96, -64, -32, 0,
     32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, 480, 512, 544, 576, 608, 640, 672, 704,
     736, 768, 800, 832, 864, 896, 928, 960, 992, 1021, 1053, 1080 }
     while (i <= #tv_ref) and (tv_val > tv_ref[i]-1) do i=i+1 end
     return tv_str[i]
end

function restore()
    set_config_value(121,0)           -- USB remote disable
    set_aflock(0)
    set_backlight(1)
    set_lcd_display(1)
    set_display(1)
end

function update_zoom()
   if ( zoom_setpoint > 0 ) then
       zsteps=get_zoom_steps()
       if(zoom_setpoint>zsteps) then zoom_setpoint=zsteps end
       printf("set zoom to step %d of %d",zoom_setpoint,zsteps)
       sleep(2000)
       set_zoom(zoom_setpoint)
       sleep(2000)
    end
end

function switch_mode( m )   -- change between shooting and playback mode
    if ( m == 1 ) then
        if ( get_mode() == false ) then
            printf("switching to record mode")
            set_record(1)
            while ( get_mode() == false ) do sleep(100) end
        end
    else
        if ( get_mode() == true) then
           printf("switching to playback mode")
           set_record(0)
           while ( get_mode() == true ) do sleep(100) end
        end
    end
end

function set_display_key(m)  -- click display key to get to desire LCD display mode
    if (m==0) then m=2 else m=0 end
    sleep(200)
    local count=5
    local clicks=0
    repeat
        disp = get_prop(props.DISPLAY_MODE)
        if ( disp ~= m ) then
            click("display")
            clicks=clicks+1
            sleep(500)
        end
        count=count-1
    until (( disp==m ) or (count==0))
    if (clicks>0) then
        if ( count>0 ) then
            printf("display changed")
       else
            printf("unable to change display")
       end
    end
    sleep(500)
end

function restore_display()
    local disp = get_prop(props.DISPLAY_MODE)
    local clicks=0
    repeat
        click("display")
        clicks=clicks+1
        sleep(500)
    until (( disp == get_prop(props.DISPLAY_MODE)) or (clicks> 5))
end

function sleep_mode(m)     --  press user shortcut key to toggle sleep mode
    printf("toggling sleep mode")
    press(SHORTCUT)
    sleep(1000)
    release(SHORTCUT)
    sleep(500)
end

function set_display(m)   --   m=0 for turn off display, m>0 turn on for m seconds
    if (display_mode>0) then
        if ( display_hold_timer>0) then
            if (m>1) then display_hold_timer = display_hold_timer+m end
        else
            if (m>1) then
                display_hold_timer = m
                m=1
            end
            local st="off"
            if (m>0) then st="on" end
            if ( display_mode==1) then
                if (display_state ~= m) then printf("set backlight %s",st) end
                sleep(1000)
                set_backlight(m)
            elseif ( display_mode==2) then
                if( display_state ~= m) then printf("set display %s",st) end
                set_display_key(m)
            elseif ( display_mode==3) then
                if( display_state ~= m ) then 
                    printf("set shooting mode %s",st)
                    switch_mode(m)
                    set_lcd_display(m)  
                    if ( m==1) then
                       update_zoom()                     
                    end
                end
            elseif ( display_mode==4) then
                if (display_state ~= m) then
                    printf("toggle sleep mode")
                    sleep_mode(m)
               end
            elseif ( display_mode==5) then
                if (display_state ~= m) then
                    printf("set LCD %s",st)
                    set_lcd_display(m)
               end
            end
            display_state=m
        end
    end
end

function led_blinker()
    if ( status_led > -1 ) then
        local tk = get_tick_count()
        if ( tk > led_timer ) then
            if ( led_state == 0 ) then
                led_state = 1
                led_timer= tk + 200
            else
                led_state = 0
                if (error_mode == 0) then
                    led_timer= tk + 2000
                else
                    led_timer= tk + 500
                end
            end
            set_led(status_led,led_state)
        end
    end
end

function camera_reboot()
    set_display(90)
    switch_mode(0)
    local ts=70
    printf("=== Scheduled reboot === : lens retraction wait")
    repeat
        printf(string.format("   rebooting in %d", ts))
        ts=ts-1
        sleep(1000)
    until ( ts == 0)
    printf("rebooting now")
    set_autostart(2)   -- autostart once
    sleep(2000)
    reboot()
end

function check_SD_card_space()
  local z=(get_free_disk_space()*100)/get_disk_size()
  if (z<5) then error_mode=1 end
  return( z )
end

function check_exposure()
    press("shoot_half")
    repeat sleep(50) until get_shooting() == true
    local tv1=get_tv96()
    local av1=get_av96()
    local sv1=get_sv96()
    local bv1=get_bv96()
    release("shoot_half")
    repeat sleep(50) until get_shooting() == false
    return tv1, av1, sv1, bv1
end

function check_dow()
    local dow = tonumber(os.date("%w"))
    if (dow_mode == 1) then
        if ( dow>0 ) and (dow < 6) then return true
        else return false
        end
    elseif (dow_mode == 2) then
        if ( dow==0 ) or (dow ==6 ) then return true
        else return false
        end
    end
    return true
end

function dawn_and_dusk(year, month, day, lat, lng, utc)   --- props to msl
    local day_of_year = 0
    local feb = 28
    if ((year % 4 == 0) and (year % 100 ~= 0 or year % 400 == 0)) then feb = 29 end
    local days_in_month = {31, feb, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    for i = 1, month-1 do
        day_of_year=day_of_year + days_in_month[i]
    end
    local doy = day_of_year + day
    local lat = lat*100
    local D = imath.muldiv(imath.sinr(imath.muldiv(16906, doy*1000-80086,1000000)), 4095, 10000)
    local time_equation = (imath.mul(imath.sinr(((337 * doy) + (465*10))/10), -171)) - (imath.mul(imath.sinr(((1787 * doy) - (168*100))/100), 130))
    local h=-6000 --civil twilight h=-6°   -- h=-833 --sunset/sunrise h=-50'
    local time_diff = 12 * imath.scale * imath.acosr(imath.div((imath.sind(h) - imath.mul(imath.sind(lat), imath.sinr(D))), imath.mul(imath.cosd(lat), imath.cosr(D)))) / imath.pi
    local top = (12 + utc) * imath.scale - imath.div(lng * 100, 15 * imath.scale) - time_equation
    local sunup  = (top - time_diff)*3600/1000
    local sundown = (top + time_diff)*3600/1000
    return sunup, sundown
end

--[[ ========================== Main Program ========================================================================= --]]

    set_console_layout(1, 1, 44, 6)
    now = get_day_seconds()
    printf("=== Started: %02d:%02d ===", now/3600, now%3600/60)

    bi=get_buildinfo()
    printf("%s %s %s %s %s", bi.version, bi.build_number, bi.platform, bi.platsub, bi.build_date)
    version= tonumber(string.sub(bi.build_number,1,1))*100 + tonumber(string.sub(bi.build_number,3,3))*10 + tonumber(string.sub(bi.build_number,5,5))
    if ( version < 120) then
        printf("Error : script needs CHDK 1.2.0 or higher")
    else
        printf("CHDK version %d okay ", version)

        -- test is this is a regular start or a reboot ?
        if ( autostarted() ) then
            sleep(1000)
            printf("Autostarted.  Next reboot:%d days", reboot_timer )
        end

        display_mode = day_display_mode
       
        -- switch to shooting mode
        switch_mode(1)
        sleep(2000)

       -- set zoom position
        update_zoom()

       -- disable flash, image stabilization and AF assist lamp
       set_prop(props.FLASH_MODE, 2)     -- flash off
       set_prop(props.IS_MODE, 3)        -- IS_MODE off
       set_prop(props.AF_ASSIST_BEAM,0)  -- AF assist off if supported for this camera
       if (ptp_enable==1) then 
            set_config_value(121,1)      -- make sure USB remote is enabled if we are going to be using PTP
       end                

       -- set timing
        now = get_day_seconds()
        timestamp = 86401
        ticsec = 0
        ticmin = 0
        set_display(60)
        tv, av, sv, bv=check_exposure()
 
        repeat
            repeat

            -- get time of day and check for midnight roll-over
                now = get_day_seconds()
                if ( now < timestamp ) then
                    printf("starting a new day")
                    ticsec=0
                    ticmin=0
                    -- update reboot timer
                    reboot_timer=reboot_timer-1
                    -- calculate start & stop times
                    dawn, dusk = dawn_and_dusk(os.date("%Y"), os.date("%m"), os.date("%d"), latitude, longitude, utc)
                    if ((dawn_mode) and ( start_time > dawn)) then day_time_start=dawn else day_time_start=start_time end
                    if ((dusk_mode) and ( stop_time < dusk )) then day_time_stop=dusk  else day_time_stop=stop_time   end
                    printf("start time : %02d:%02d stop time : %02d:%02d",day_time_start/3600, day_time_start%3600/60,day_time_stop/3600,  day_time_stop%3600/60)
                end
                timestamp=now

             -- process things that happen once every 15 seconds
                if ( ticmin <= now ) then
                    ticmin = now+15
                 -- manage display / backlight
                    set_display(0)
                    collectgarbage()
                -- check battery voltage
                    local vbatt=get_vbatt()
                    if ( vbatt < low_batt_trip ) then
                        batt_trip_count = batt_trip_count+1
                        if (batt_trip_count>3) then
                            printf("low battery shutdown : ".. vbatt)
                            sleep(2000)
                            post_levent_to_ui('PressPowerButton')
                        end
                    else batt_trip_count = 0 end
                    -- Day or Night mode ? enabled today ?  day or night mode ?  inverted start & stop times ? tv above minimum threshold ?
                    if ( check_dow() ) then
                        if (     ((day_time_start <  day_time_stop) and ( (now>day_time_start) and (now<day_time_stop)))
                             or  ((day_time_start >  day_time_stop) and ( (now>day_time_start)  or (now<day_time_stop)))
                             or  (tv>=min_Tv+24) ) then
                                if ( shooting_mode == NIGHT ) then    
                                   set_display(4)                       -- turn the display on
                                   display_mode = day_display_mode      -- set new display power saving mode   
                                   printf("switching to day mode")
                                   shooting_mode = DAY
                                end
                        else
                            if (( shooting_mode == DAY ) and (tv<=min_Tv))then
                                set_display(4)                          -- turn the display on
                                display_mode = night_display_mode       -- set new display power saving mode                               
                                printf("switching to night mode")
                                shooting_mode = NIGHT                             
                            end
                        end
                    else shooting_mode = NIGHT end
                end

            -- process things that happen once per second
                if ( ticsec <= now ) then
                    ticsec = now+1
                    -- console_redraw()
                    if( display_hold_timer>0) then display_hold_timer=display_hold_timer-1 end

                    -- check if the USB port connected and switch to playback to allow image downloading?
                    if ((ptp_enable==1) and (get_usb_power(1)==1)) then
                        printf("**PTP mode requested")
                        switch_mode(0)
                        set_config_value(121,0)           -- USB remote disable
                        sleep(1000)
                        repeat
                            sleep(100)
                        until (get_usb_power(1)==0)
                        printf("**PTP mode released")
                        sleep(2000)
                        set_config_value(121,1)           -- USB remote enable
                        sleep(2000)
                        switch_mode(1)
                        sleep(1000)
                    end
                end

            -- blink status LED  - slow (normal) or fast(error or SD card full)
                led_blinker()

            -- time for a reboot ? ( days between reboot expired and 1:00 AM )
                if (( reboot_timer < 0 ) and ( now > reboot_hour )) then camera_reboot() end

                -- check exposure if tv mode enable - do it every time in day mode and every 10 minutes in night mode
                if ( (min_Tv < 9990) and ((shooting_mode == DAY) or (get_day_seconds()%600==0)) ) then
                    -- restore display if using sleep mode or playback mode to save power/backlight
                    if (display_mode>2) then set_display(1) end
                    tv, av, sv, bv=check_exposure()                    
                end

              -- shoot if in day mode
                if (shooting_mode == DAY) then
                    if(focus_at_infinity == 1) then 
                        set_focus(50000)
                        sleep(500)  
                    end              
                    press("shoot_half")
                    repeat sleep(10) until (get_shooting()==true)
                    if ( detect_motion(threshold, delay) >0 ) then
                        shot_counter = shot_counter+1
                        shotstring = "Shot:"..shot_counter
                    else
                        shotstring = "No shot:"
                    end
                    release("shoot_half")
                    tv, av, sv, bv=check_exposure()
                    fs = av96_to_aperture(av)
                    fstop = (fs/1000).."."..(fs%1000)/100     
                    vb = get_vbatt()
                    vbatt = (vb/1000).."."..((vb%1000)/100).."V"   
                    printf("%s tv:%s f%s ISO%d %s", shotstring, tv2seconds(tv), fstop, sv96_to_iso(sv), vbatt)
                end

          -- check for user input from the keypad
                wait_click(100)

            until not( is_key("no_key"))
            print("key pressed")
            set_display(30)
        until is_key("menu")
        print("menu key exit")
    end
restore()



