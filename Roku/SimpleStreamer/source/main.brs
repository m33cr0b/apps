''
'' This is the entry point of the application. The user interface sits
'' in a forever loop. Only the home button exists the channel.
''
Sub RunUserInterface()
    o = Setup() 
    while true  
        print "In the while loop" 
        msg = o.showHomeScreen()
        print "Before Home screen msg msg"
        print "Home scrren msg = "; msg      
        if msg < 0 
           print "Exiting  the while loop"   
           exitwhile
        end if   
        
        print "Before o.setup()"
        o.setup()
        o.paint()
        o.eventloop()
    end while
    print "App has gone into afterlife"   
End Sub

''
'' Setup the global object. All channel video configuration is setup here.
''
Function Setup() As Object
    this = {
        port:      CreateObject("roMessagePort")
        progress:  0 'buffering progress
        position:  0 'playback position (in seconds)
        paused:    false 'is the video currently paused?
        fonts:     CreateObject("roFontRegistry") 'global font registry
        canvas:    CreateObject("roImageCanvas") 'user interface
        player:    CreateObject("roVideoPlayer")
        setup:     SetupFullscreenCanvas
        paint:     PaintFullscreenCanvas
        eventloop: EventLoop
        urls: CreateObject("roArray", 5, true)
        play:   Play
        showHomeScreen: ShowHomeScreen
        showList: CreateObject("roArray", 10, true)
        lastSelectedStream: 0
    }

    'Static help text:
    this.help = "Press the right or left arrow buttons on the remote control "
    this.help = this.help + "to seek forward or back through the video at "
    this.help = this.help + "approximately one minute intervals.  Press down "
    this.help = this.help + "to toggle fullscreen."

    'Register available fonts:
    this.fonts.Register("pkg:/fonts/caps.otf")
    this.textcolor = "#406040"

    'Setup image canvas:
    this.canvas.SetMessagePort(this.port)
    this.canvas.SetLayer(0, { Color: "#000000" })
    this.canvas.Show()

    'Resolution-specific settings:
    mode = CreateObject("roDeviceInfo").GetDisplayMode()
    if mode = "720p"
        this.layout = {
            full:   this.canvas.GetCanvasRect()
            top:    { x:   0, y:   0, w:1280, h: 130 }
            left:   { x: 249, y: 177, w: 391, h: 291 }
            right:  { x: 700, y: 177, w: 350, h: 291 }
            bottom: { x: 249, y: 500, w: 780, h: 300 }
        }
    else
        this.layout = {
            full:   this.canvas.GetCanvasRect()
            top:    { x:   0, y:   0, w: 720, h:  80 }
            left:   { x: 100, y: 100, w: 280, h: 210 }
            right:  { x: 400, y: 100, w: 220, h: 210 }
            bottom: { x: 100, y: 340, w: 520, h: 140 }
        }
    end if

    this.player = CreateObject("roVideoPlayer")
    rect = { x:0, y:0, w:0, h:0 } 'fullscreen
    this.player.SetDestinationRect(0, 0, 0, 0) 'fullscreen
    this.player.SetDestinationRect(rect)   

    this.urls = GetUrlList()
    
    this.showList = GetVideoList()

    'EnableBackButton(true)
    
    return this
End Function

''
'' Retrieve a list of stream urls for the videos.xml file.
''
Function GetUrlList() As Object
    rsp=CreateObject("roXMLElement")    
    rsp.Parse(ReadAsciiFile("pkg:/videos.xml"))

    categories = rsp.categories.category
    print "before for each"
    for each category in categories 
        videos = category.videos.video
        print "category.videos type: ";type(category.videos)
        
        urls = CreateObject("roArray", videos.Count(), true)
        for i = 0 to (videos.Count() - 1)          
            print "loop"; videos[i].title.GetText()
            urls[i] = videos[i].url.GetText()
        end for     
        
        return urls      
    end for
End Function

''
'' Retrieve the home screen thumbnail url, title, and description.
''
Function GetVideoList() As Object
    rsp=CreateObject("roXMLElement")    
    rsp.Parse(ReadAsciiFile("pkg:/videos.xml"))

    categories = rsp.categories.category
    print "before for each"
    for each category in categories 
        videos = category.videos.video
        print "category.videos type: ";type(category.videos)
        
        showList = CreateObject("roArray", videos.Count(), true)
        for each video in videos
          
            print "loop"; video.title.GetText()
                videoInfo = {
                ShortDescriptionLine1:video.title.GetText(),
                ShortDescriptionLine2:video.description.GetText(),
                HDPosterUrl:video.thumbnail_url.GetText(),
                SDPosterUrl:video.thumbnail_url.GetText()
            }
            showList.Push(videoInfo)
        end for     
        
        return showList      
    end for
End Function
   
''
'' This method displays the home screen, and waits for key press events. Once
'' a video is selected, then the event loop method waits for key presses.
''
Function ShowHomeScreen() As Object

    port=CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)
    
    screen.SetContentList(m.showList)   
    screen.SetFocusedListItem(m.lastSelectedStream)
    screen.Show()

    break_out = 0
    

    while true and break_out = 0
        print "Home screen waiting for an event"
        
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
            print "showPosterScreen | msg = "; msg.GetMessage() " | index = "; msg.GetIndex() " | type = "; msg.GetType()
            index = msg.GetIndex()               
            print "Msg index: " + index.tostr()
            if msg.GetType() = 1 and (index = 0 or index = 2)  '<UP> or <BACK>    
                print "Back or up pressed: " + index.tostr()           
                print "Home screen exiting, returning -1"
                screen.Close()
                return -1   
            else if msg.isListFocused() then
                'get the list of shows for the currently selected item                       
                print "list focused | current category = "; msg.GetIndex()
            else if msg.isListItemFocused() then
                print"list item focused | current show = "; msg.GetIndex()
            else if msg.isListItemSelected() then
                print "list item selected | current show = "; msg.GetIndex() 
                videoIndex = msg.GetIndex()

                m.lastSelectedStream = videoIndex
                m.play(videoIndex)
                break_out = 1
            else if msg.isListItemInfo() then      ' INFO BUTTON PRESSED
                DisplayInfoMenu(msg.getindex())
            else if msg.isScreenClosed() then
                print "Home screen exiting, returning -1"
                screen.Close()
                return -1     
            end if
        end If
    end while
    print "Home screen exiting, returning "
    screen.Close()
    return 0
End Function

''
'' Start playing a video given a selected video index.
''
Function Play (index As Integer)
    print "In Play index: "; index

    m.player.SetMessagePort(m.port)
    m.player.SetLoop(true)
    m.player.SetPositionNotificationPeriod(1)
    m.player.SetDestinationRect(m.layout.full)
    m.player.SetContentList([{
        Stream: { url: m.urls[index]}
        StreamFormat: "hls"
    }])
    m.player.Play()
End Function

''
'' The eventloop. This method waits for keypresses while the video is playing.
''
Sub EventLoop()

    while true
        print "Player waiting for an event"
        msg = wait(0, m.port)
        if msg <> invalid
            'If this is a startup progress status message, record progress
            'and update the UI accordingly:                  
            if msg.isStatusMessage() and msg.GetMessage() = "startup progress"
                m.paused = false
                progress% = msg.GetIndex() / 10
                if m.progress <> progress%
                    m.progress = progress%
                    m.paint()
                end if

            'Playback progress (in seconds):
            else if msg.isPlaybackPosition()
                m.position = msg.GetIndex()
                m.paint()

            'If the <UP> key is pressed, jump out of this context:
            else if msg.isRemoteKeyPressed()
                index = msg.GetIndex()
                print "Remote button pressed: " + index.tostr()
                if index = 0 or index = 2 '<UP> or <BACK>
                    m.player.Stop()
                    'm.showHomeScreen()
                    return
                'else if index = 3 '<DOWN> (toggle fullscreen)
                    '    no operation
                else if index = 4 or index = 8  '<LEFT> or <REV>
                    m.lastSelectedStream = m.lastSelectedStream - 1
                    if m.lastSelectedStream < 0
                       m.lastSelectedStream = m.urls.Count() - 1
                    end if
                    m.play(m.lastSelectedStream)
                else if index = 5 or index = 9  '<RIGHT> or <FWD>
                    m.lastSelectedStream = m.lastSelectedStream + 1
                    if m.lastSelectedStream = m.urls.Count() 
                       m.lastSelectedStream = 0  
                    end if
                    m.play(m.lastSelectedStream)
                else if index = 13  '<PAUSE/PLAY>
                    if m.paused m.player.Resume() else m.player.Pause()
                end if

            else if msg.isPaused()
                m.paused = true
                m.paint()

            else if msg.isResumed()
                m.paused = false
                m.paint()

            end if
            'Output events for debug
            print msg.GetType(); ","; msg.GetIndex(); ": "; msg.GetMessage()
        end if
    end while
End Sub

''
'' Get the full screen mode ready.
''
Sub SetupFullscreenCanvas()
    m.canvas.AllowUpdates(false)
    m.paint()
    m.canvas.AllowUpdates(true)
End Sub

''
'' Print "Loading..." or "Paused" while in full screen mode.
''
Sub PaintFullscreenCanvas()
    list = []

    if m.progress < 100
        color = "#000000" 'opaque black
        list.Push({
            Text: "Loading..." + m.progress.tostr() + "%"
            TextAttrs: { font: "huge" }
            TargetRect: m.layout.full
        })
    else if m.paused
        color = "#80000000" 'semi-transparent black
        list.Push({
            Text: "Paused"
            TextAttrs: { font: "huge" }
            TargetRect: m.layout.full
        })
    else
        color = "#00000000" 'fully transparent
    end if

    m.canvas.SetLayer(0, { Color: color, CompositionMode: "Source" })
    m.canvas.SetLayer(1, list)
End Sub

