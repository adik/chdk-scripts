--[[
@title Battery Miser 6.1
@param s Interval (sec)
@default s 60
@param b Turn Backlight Off
@default b 0
@range b 0 1
@param d Turn Display Off
@default d 0
@range d 0 1
@param p Wait in Playback Mode
@default p 0
@range p 0 1
@param k Use shortcut key to sleep
@default k 0
@range k 0 1
@param a Enable AF Lock
@default a 0
@range a 0 1
@param l Log to File
@default l 1
@range l 0 1
@param r Lens Retract Delay (sec)
@default r 60
@param v Batttery Stop Voltage (mV)
@default v 1000
@range v 0 10000
--]]
 
props=require("propcase")
 
shortcut_key="print"   -- edit this if using shortcut key to enter sleep mode
sleep_mode=false
 
 
function restore()
    set_backlight(1)
    set_aflock(0)
    sleep_disable()
end
 
function sleep_enable()
  if( sleep_mode==false) then
      print("enter sleep mode via shortcut")
      press(shortcut_key)
      sleep(2000)
      release(shortcut_key)
      sleep_mode=true
  end
end
 
function sleep_disable()
  if( sleep_mode==true) then
      print("exit sleep mode via shortcut")
      press(shortcut_key)
      sleep(2000)
      release(shortcut_key)
      sleep_mode=false
  end
end
 
 
function log_to_file( string )
   if ( l == 1 ) then
      print_screen(-10)
         print(string)
      print_screen(false)
   else
     print(string)
   end
end
 
 
function switch_mode( m )   -- change between shooting and playback mode
   if ( m == 1 ) then
      if ( get_mode() == false ) then
         print("switching to record mode")
         set_record(1)
         while ( get_mode() == false ) do
            sleep(100)
         end
      end
   else
      if ( get_mode() == true ) then
         print("switching to playback mode")
         set_record(0)
         while ( get_mode() == true ) do
            sleep(100)
         end
       end
   end
end
 
function display_off()   -- turn off display by pressing DISP button
   print("blanking display")
   count=5
   disp_save = get_prop(props.DISPLAY_MODE)   
   repeat
      disp = get_prop(props.DISPLAY_MODE)   
      if ( disp ~= 2 ) then
          click("display")
          sleep(500)
      end
      count=count-1
   until ((disp==2) or (count==0))
   if ( count>0 ) then 
       print("display blanked")
   else
       print("unable to blank the display")
   end
end
 
set_console_layout(0,0,45,12)
 
if ( l==1 ) then
   print_screen(-10)
   print("  ")
   print("============================================")
   print(os.date("%d.%m.%y  %X"))
   print("interval=",s,"retract=",r,"AFL=",a)
   print("backlight=",b,"playback_idle=",p)
   print("display off=",d, "vbatt cutout=", v)
   print("sleep mode=",k,"logging=",d)
   print("============================================")
   print_screen(false)
end
 
sleep(2000)
 
shotcount=0
interval=s*1000
retract=r*1000
b=1-b
 
 
switch_mode(1)
 
if( a == 1 ) then            -- focus lock ?
    press( "shoot_half" )
    while ( get_shooting() == true ) do
      sleep(100)
    end
    release("shoot_half")
    set_aflock(1)
    print( "--focus locked")
    sleep(500)
end
 
if ( d==1 ) then             -- turn display off ?
   if( p==1 ) then 
	print("**Warning: Wait in Playback mode")
	print("**conflicts with Display Off mode.")
        print("**Disabling Playback Idle mode")
        sleep(2000)
        p=0
   end
   display_off()
   sleep(5000)
end
 
 
battery = get_vbatt()
nextshot=get_tick_count()
start=nextshot
abort = false
 
 
-- intervalometer loop starts here
 
repeat 
   switch_mode(1)
   print("short wait =", (nextshot-get_tick_count())/1000 )
   while (nextshot > get_tick_count()) do
     set_backlight(b)
     sleep(500)
   end
 
   shotcount = shotcount + 1
   tic  = get_tick_count()-start
   nextshot = nextshot + interval
   lens_retract = get_tick_count() + retract
   log_to_file(string.format("shot:%d %2.2d:%2.2d %d.%2.2dV", shotcount, tic/3600000, (tic%3600000)/60000, battery/1000, (battery%1000)/10))
 
   if (k==1) then sleep_disable() end
 
   shoot()
 
   sleep(200)
 
   if( p==1) then switch_mode(0) end
 
   if (k==1) then sleep_enable() end
 
   print( "next shot wait ..", (nextshot-get_tick_count())/1000 )
   repeat
      if( (p==1) and (lens_retract < (get_tick_count()+2000) )) then
         switch_mode(1)
         switch_mode(0)
         lens_retract = get_tick_count() + retract
      end
      set_backlight(b)
      battery = (get_vbatt() + (battery*15)) / 16
      if ( battery < v ) then abort=true end
      if ( is_pressed("menu")) then abort=true end
      sleep(100)
   until ((nextshot < (get_tick_count()+3000) ) or abort)
until ( abort )
 
-- all done - user abort or battery below limit
 
if( battery < v ) then
   log_to_file("battery limit reached")
else
   log_to_file("user abort")
end
 
if ( d==1 ) then
   print("unblanking display")
   count=5
   repeat
      disp = get_prop(props.DISPLAY_MODE)
      if ( disp ~= disp_save) then
         click("display")
         sleep(500)
      end
      count=count-1
   until ((disp==disp_save) or (count==0))
end
restore()