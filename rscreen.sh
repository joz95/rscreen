#!/bin/bash

rscreen () {
    # function to record full screen monitor and audio out.
    #  
    echo "[I] Identifiying monitors ..."
    sleep 1

    # identify  monitors  connected to the  machine and create an associative
    # array to store monitor, video size and position, parameters required by
    # ffmpeg command
    #
    # using xrandr to identify minitors and manipulating IFS to generate CSV
    # output, like:
    #     eDP-1 1920x1080+0+0 1,HDMI-1 1920x1080+1921+0,
    #
    # result will be put into an indexed array
    #
    IFS=",";scr=($(xrandr | grep " connected"| awk -F " " -v ORS="," \
               '{if ($3 == "primary")\
                   {print $1 " " $4 " 1"} else  print $1 " " $3}'))
    
    # declaring the associative array to save info about monitors, screen size
    # and positio, as well as the primary monitor.
    #
    declare -A a_scr
   
    # looping through $scr to generate inputs for the associative array. 
    for i in ${scr[@]}
    do
        [ "$(echo $i|awk '{print $3}')" == 1 ] && \
            s_prim=$(echo $i|awk '{print $1}') 
    
        s=$(echo $i|awk '{print $1}')
    
        s_p=$(echo $i|awk '{print $2}')
        s_size=$(echo ${s_p%%+*})
        s_pos=$(echo ${s_p#*+})
    
        a_scr[$s]="$s_size $s_pos"
    done
    
    IFS=" "
    
    # user interaction
    # 
    echo -e "[I] Which monitor to record?"
    echo -e "[I] Options: " ${!a_scr[@]}
    echo -e "[I] press <ENTER> to use default monitor [$s_prim]" 

    read -p "> " _mon
    
    echo -e "[I] Which audio to record?"
    echo -e "0. audio out\n1. audio in+out"

    read -p "> " _aud
    
    # setting audio to record (atr var)
    #
    if [ -z $_aud ]; then
        atr="out"
    else
        aud=(0 1)
        if ! [ ${aud[$_aud]+set} ]; then
            echo -e "[E] Audio option unavailable!"
            return 1
        fi

        if [ $_aud == 0 ]; then 
           atr="out"
        else
           atr="inout" 
        fi
    fi

    ### START OF VIDEO PARAMETERS DEFINITIONS ###
    
    # check if $_mon is empty (<ENTER> pressed) and set variables for video_size
    # $(vs) and position ($po) accordingly to use the default monitor
    #
    if [ -z "$_mon" ]
    then
        vs=$(echo ${a_scr[$s_prim]}|awk '{print $1}')
        po=$(echo ${a_scr[$s_prim]}|awk '{print $2}'|sed 's/+/,/')

    # else check if input is a valid option (monitor exist in array) and set
    # variables for video_size ($vs) and position ($po) accordingly to use 
    # the chosen monitor
    else
        if [ -z ${a_scr[$_mon]} ]; then
             echo -e "[E] Monitor not connected!"
             return 1
        fi
        vs=$(echo ${a_scr[$_mon]}|awk '{print $1}')
        po=$(echo ${a_scr[$_mon]}|awk '{print $2}'|sed 's/+/,/')
    fi

    ### END OF VIDEO PARAMETERS DEFINITIONS ###

    ### START OF AUDIO PARAMETERS DEFINITIONS ###

    # identify default audio input and output
    a_in=$(pacmd list-sources |grep -E "\* index:" |awk '{print $3}')
    let a_out=$(pacmd list-sources |grep -E "\* index:" |awk '{print $3}')-1

    # check if headset is conected (bluetooth or usb devices) and use it as
    # source overriding default audio sources.
    #
    a_ext_int=(`pactl list short sources |grep -E "blue|usb" |cut -f 1`)

    if [ ${#a_ext_int[@]} -gt 1 ]
    then
        a_in=${a_ext_int[1]}
        a_out=${a_ext_int[0]}
    fi

    ### END OF AUDIO PARAMETERS DEFINITIONS ###

    # execute ffmpeg to capture screen and audio according to $atr 
    #
    if [ $atr == "out" ]
    then
       ffmpeg -hide_banner -y \
           -video_size $vs\
           -framerate 30 \
           -f x11grab -i :0.0+$po \
           -thread_queue_size 512 \
           -f pulse -i $a_out \
           -c:a libvorbis \
           /tmp/screen_and_audio_out.mkv
    else 
       ffmpeg -hide_banner -y \
           -video_size $vs \
           -framerate 30 \
           -f x11grab -i :0.0+$po \
           -thread_queue_size 512 \
           -f pulse -filter_complex amerge -ac 2 -i $a_in \
           -f pulse -ac 2 -i $a_out \
           -c:v libx264rgb \
           -crf 0 -preset ultrafast \
           /tmp/screen_and_audio_in_out.mkv
    fi
}

rscreen_in_out () {
    
    # function to record screen, audio out and audio in

    # set default audio sources
    a_in=$(pacmd list-sources |grep -E "\* index:" |awk '{print $3}')
#    a_out=$(pacmd list-sinks |grep -E "\* index:" |awk '{print $3}')
    let a_out=$(pacmd list-sources |grep -E "\* index:" |awk '{print $3}')-1


    # check if headset is conected (bluetooth or usb devices) and use it as 
    # source overriding default audio sources. 
    #
    a_ext_int=(`pactl list short sources |grep -E "blue|usb" |cut -f 1`)

    if [ ${#a_ext_int[@]} -gt 1 ]
    then
        a_in=${a_ext_int[1]}
        a_out=${a_ext_int[0]}
    fi
    
    # capture screen and mixed in and out audio sources
    ffmpeg -hide_banner -y \
        -video_size 1920x1080 \
        -framerate 30 \
        -f x11grab -i :0.0+0,0 \
        -thread_queue_size 512 \
        -f pulse -filter_complex amerge -ac 2 -i $a_in \
        -f pulse -ac 2 -i $a_out \
        -c:v libx264rgb \
        -crf 0 -preset ultrafast \
        /tmp/screen_and_audio_in_out.mkv
}

record_mic () {

    # identify default audio input
    a_in=$(pacmd list-sources |grep -E "\* index:" |awk '{print $3}')

    # check if headset is connected and use it as source overriding default
    # audio sources. Command will check for bluetooth or usb devices.
    #
    a_ext_int=(`pactl list short sources |grep -E "blue|usb" |cut -f 1`)

    if [ ${#a_ext_int[@]} -gt 1 ]
    then
        a_in=${a_ext_int[1]}
    fi

    ffmpeg -hide_banner -y \
        -f pulse \
        -i $a_in -c:a libopus\
        /tmp/audio.opus
}

record_audio_in_out () {

    # set default audio sources
    a_in=$(pacmd list-sources |grep -E "\* index:" |awk '{print $3}')
    a_out=$(pacmd list-sinks |grep -E "\* index:" |awk '{print $3}')

    # check if headset is conected and use it as source overriding default
    # audio sources. Command will check for bluetooth or usb devices.
    #
    a_ext_int=(`pactl list short sources |grep -E "blue|usb" |cut -f 1`)

    if [ ${#a_ext_int[@]} -gt 1 ]
    then
        a_in=${a_ext_int[1]}
        a_out=${a_ext_int[0]}
    fi
        
    ffmpeg -hide_banner -y \
        -f pulse -i $a_in \
        -f pulse -i $a_out \
        -c:a libopus \
        -filter_complex [0:a:0][1:a:0]amix=2 \
        -c:a libopus \
        /tmp/audio_in_out.opus
}

record_cam () {
    ffmpeg -y \
        -f v4l2 \
        -framerate 30 \
        -video_size 640x480 \
        -i /dev/video0 \
        /tmp/output.mkv
}

