'
' @author Michel Lacle, Oksana Kohutyuk
' @copyright All rights reserved, Michel Lacle 2011
'
Sub Main()

    initTheme()

    'prepare the screen for display and get ready to begin
    screen=preShowPosterScreen("", "")
    if screen=invalid then
        print "unexpected error in preShowPosterScreen"
        return
    end if

    showPosterScreen(screen)

End Sub


Sub initTheme()

    app = CreateObject("roAppManager")
    theme = CreateObject("roAssociativeArray")

    theme.OverhangOffsetSD_X = "30"
    theme.OverhangOffsetSD_Y = "22"
    theme.OverhangSliceSD = "pkg:/images/overhang_background_slice_SD.png"
    theme.OverhangLogoSD  = "pkg:/images/Logo_Overhang_SD.png"


    theme.OverhangOffsetHD_X = "15"
    theme.OverhangOffsetHD_Y = "60"
    theme.OverhangSliceHD = "pkg:/images/Overhang_BackgroundSlice_HD.png"
    theme.OverhangLogoHD  = "pkg:/images/Logo_Overhang_HD.png"

    theme.BackgroundColor = "#FFFFFF"
    theme.FilterBannerSliceHD = "pkg:/images/banner_filter_HD.png"
    theme.FilterBannerSliceSD = "pkg:/images/banner_filter_SD.png"
    
    app.SetTheme(theme)
End Sub

'******************************************************
'** Perform any startup/initialization stuff prior to 
'** initially showing the screen.  
'******************************************************
Function preShowPosterScreen(breadA=invalid, breadB=invalid) As Object

    port=CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)
    if breadA<>invalid and breadB<>invalid then
        screen.SetBreadcrumbText(breadA, breadB)
    end if


    screen.SetListStyle("arced-landscape")
    return screen

End Function


Function showPosterScreen(screen As Object) As Integer
    screen.Show()
    
    'add dialog
    m.videosXml = GetVideosXml()

    categoryList = getCategoryList()
    screen.SetListNames(categoryList)
    screen.SetContentList(getShowsForCategoryItem(categoryList[0]))


    lastSelectedDateIndex = 0

    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
            print "showPosterScreen | msg = "; msg.GetMessage() " | index = "; msg.GetIndex() " | type = "; msg.GetType()
            if msg.isListFocused() then
                'get the list of shows for the currently selected item
                screen.SetContentList(getShowsForCategoryItem(categoryList[msg.GetIndex()]))
                
                lastSelectedDateIndex = msg.GetIndex()                

                print "list focused | current category = "; msg.GetIndex()
            else if msg.isListItemFocused() then
                print"list item focused | current show = "; msg.GetIndex()
            else if msg.isListItemSelected() then
                print "list item selected | current show = "; msg.GetIndex() 

                videoIndex = msg.GetIndex()

	        videoArgs = GetVideoArgs(lastSelectedDateIndex, videoIndex)
                displayVideo(videoArgs)
            else if msg.isListItemInfo() then      ' INFO BUTTON PRESSED
		        DisplayInfoMenu(msg.getindex())
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while

End Function

Function GetVideoArgs(categoryIndex As Integer, videoIndex As Integer) As Object

    videoXmls = m.videosXml

    category = videoXmls.categories.category[categoryIndex]
    video = category.videos.video[videoIndex]
    
    videoArgs = CreateObject("roAssociativeArray")
    videoArgs.url = video.url.GetText()
    videoArgs.title = video.title.GetText()

    print "URL - TITLE"
    print videoArgs.url
    print videoArgs.title

    return videoArgs
End Function


Function GetMpegInfo(categoryIndex As Integer, videoIndex As Integer) As Object

    videoXmls = m.videosXml    

    date = videoXmls.dates.date[categoryIndex]
    video = date.videos.video[videoIndex]

    itemMpeg = {   ContentType:"episode"
               SDPosterUrl:"file://pkg:/images/tsn.gif"
               HDPosterUrl:"file://pkg:/images/tsn.gif"
               IsHD:False
               HDBranded:False
               ShortDescriptionLine1:""
               ShortDescriptionLine2:""
               Description:video.description.GetText()
               Rating:"NR"
               StarRating:"80"
               Length:1280
               Categories:["Technology","Talk"]
               Title:video.title.GetText()
               }

    return itemMpeg
End Function



Function DisplayInfomenu(infotype)
	infomenu = createobject("romessagedialog")
	infomenu.setmessageport(createobject("romessageport"))
	infomenu.enableoverlay(true)
	if (infotype = 0)
		infomenu.setmenutopleft(true)
		infomenu.addbutton(1,"button 1")
		infomenu.addbutton(2,"button 2")
		infomenu.addratingbutton(2,0,50,"billions rated")
		infomenu.addbutton(4,"exit")
	elseif (infotype = 1)
		infomenu.setTitle("Dialog Overlay")
		infomenu.settext("This is an example paragraph that can be added to this dialog before putting up some buttons")
		infomenu.addbutton(1,"button 1")
		infomenu.addbutton(2,"button 2")
		infomenu.addbutton(4,"exit")
		infomenu.setfocusedmenuitem(2)		' 3rd button
        else
		infoMenu.setTitle("Info Overlay")
		infoMenu.settext("Additional information here with a simple dismiss/quit/exit/done button")
		infomenu.addbutton(4,"done")
	endif
	infomenu.show()
	while true
		msg = wait(0,infomenu.getmessageport())
		if msg.isscreenclosed() return 0
		if msg.isButtonInfo() return 0   ' Info pressed again, dismiss the info overlay
		if msg.isbuttonpressed()
			button = msg.getindex()
			print "Info Button ";button;" pressed"
			if button = 4
				return button
			endif
		endif
	end while
end function

Function getCategoryList() As Object
    print "In getCategoryList()"

    videoXmls = m.videosXml    

    categories = videoXmls.categories.category
    
    categoryList = CreateObject("roArray", 10, true)

    for each category in categories
       print "adding category: "; category.name.GetText()
       categoryList.Push(category.name.GetText())
    end for

    return categoryList
End Function


Function getShowsForCategoryItem(selectedCategory As Object) As Object

    print "getting shows for category "; selectedCategory

    videoXmls = m.videosXml    

    categories = videoXmls.categories.category
    
    showList = CreateObject("roArray", 10, true)

    print "before for each"

    for each category in categories
    
       if category.name.GetText() = selectedCategory
          print "found category"; category.name.GetText()
          
          videos = category.videos.video
          print "category.videos type: ";type(category.videos)
          
	  print "Count videos: ";videos.Count()          
	  print "Video count: "; videos.video.Count()	

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
       end if
    end for

    return showList

End Function

'
'
'
Function displayVideo(args As Dynamic)
    print "Displaying video: "
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)

    bitrates  = [0]    

    urls = [""]
    
    qualities = ["SD"]
    StreamFormat = "mp4"
    
    srt = ""

    urls[0] = args.url
    title = args.title
    
    videoclip = CreateObject("roAssociativeArray")
    videoclip.StreamBitrates = bitrates
    videoclip.StreamUrls = urls
    videoclip.StreamQualities = qualities
    videoclip.StreamFormat = StreamFormat
    videoclip.Title = title
    print "srt = ";srt
    if srt <> invalid and srt <> "" then
       videoclip.SubtitleUrl = srt
    end if
    
    video.SetContent(videoclip)
    video.show()

    lastSavedPos   = 0
    statusInterval = 10 'position must change by more than this number of seconds before saving

    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                print "Closing video screen"
                exit while
            else if msg.isPlaybackPosition() then
                nowpos = msg.GetIndex()
                if nowpos > 10000
                    
                end if
                if nowpos > 0
                    if abs(nowpos - lastSavedPos) > statusInterval
                        lastSavedPos = nowpos
                    end if
                end if
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
                print msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
End Function

Function GetVideosXml() As Object
    urlTransfer = CreateObject("roUrlTransfer")
    urlTransfer.SetUrl("http://michel.f1kart.com/video_station/railscasts")    
    raw_xml = urlTransfer.GetToString()

    videoXmls=CreateObject("roXMLElement")
    videoXmls.Parse(raw_xml)    
    
    return videoXmls
End Function
