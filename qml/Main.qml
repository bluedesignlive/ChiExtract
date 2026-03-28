import QtQuick
import QtQuick.Layouts
import Chi
import ChiExtract.Backend 1.0

ChiApplicationWindow {
    id: root; title:"ChiExtract"; width:470; height:590; minimumWidth:420; minimumHeight:560
    property int mode: 0
    property var colors: ChiTheme.colors
    ArchiveManager { id: mgr }

    showMenu:true; showDefaultMenus:false
    customMenus:[
        {id:"file",title:"File",items:[
            {id:"open",text:"Open Archive",shortcut:"Ctrl+O",icon:"folder_open"},
            {id:"create",text:"New Archive",shortcut:"Ctrl+N",icon:"note_add"},
            {type:"divider"},{id:"clear",text:"Clear",icon:"clear_all"},
            {type:"divider"},{id:"exit",text:"Exit",shortcut:"Alt+F4",icon:"logout"}]},
        {id:"edit",title:"Edit",items:[
            {id:"settings",text:"Settings",shortcut:"Ctrl+,",icon:"settings"}]},
        {id:"view",title:"View",items:[
            {id:"theme",text:"Toggle Dark Mode",shortcut:"Ctrl+T",icon:"dark_mode"}]},
        {id:"help",title:"Help",items:[
            {id:"about",text:"About ChiExtract",icon:"info"}]}]

    onMenuItemTriggered:function(m,i){
        if(m==="file"){if(i==="open"){mode=0;exV.openFileBrowser()}else if(i==="create")mode=1;
            else if(i==="clear"){mgr.clear();mgr.clearFiles()}else if(i==="exit")close()}
        else if(m==="edit"&&i==="settings")settingsDlg.visible=true
        else if(m==="view"&&i==="theme")ChiTheme.toggleDarkMode()
        else if(m==="help"&&i==="about")aboutDlg.visible=true}

    Shortcut{sequence:"Ctrl+O";onActivated:{mode=0;exV.openFileBrowser()}}
    Shortcut{sequence:"Ctrl+N";onActivated:mode=1}
    Shortcut{sequence:"Ctrl+T";onActivated:ChiTheme.toggleDarkMode()}
    Shortcut{sequence:"Ctrl+,";onActivated:settingsDlg.visible=true}

    DropArea{id:wD;anchors.fill:parent;z:50;keys:["text/uri-list"]
        onDropped:function(d){if(!d.urls.length)return;if(mode===0)mgr.openArchive(d.urls[0].toString());
            else{var p=[];for(var i=0;i<d.urls.length;i++)p.push(d.urls[i].toString());mgr.addFiles(p)}}}
    Rectangle{anchors.fill:parent;z:45;color:colors.primary;opacity:wD.containsDrag?0.04:0;visible:opacity>0;Behavior on opacity{NumberAnimation{duration:150}}}

    Item{anchors.fill:parent;anchors.margins:28;z:1
        ColumnLayout{anchors.horizontalCenter:parent.horizontalCenter;anchors.top:parent.top;anchors.bottom:parent.bottom;width:Math.min(parent.width,600);spacing:0
            Item{Layout.fillWidth:true;Layout.preferredHeight:52;SegmentedButton{anchors.centerIn:parent;segments:[{text:"Extract"},{text:"Create"}];selectedIndex:mode;onSelectionChanged:function(i){mode=i[0]}}}
            Item{Layout.preferredHeight:16}

            // No clip — lets animations breathe beyond edges
            Item{Layout.fillWidth:true;Layout.fillHeight:true

                ExtractView{
                    id:exV;anchors.fill:parent;manager:mgr
                    dragActive:wD.containsDrag&&mode===0
                    onExtractRequested:extractFlow.start()

                    transform:Translate{id:exTx;x:0}
                    opacity:1

                    states:[
                        State{name:"active";when:mode===0
                            PropertyChanges{target:exTx;x:0}
                            PropertyChanges{target:exV;opacity:1;visible:true}},
                        State{name:"inactive";when:mode!==0
                            PropertyChanges{target:exTx;x:-60}
                            PropertyChanges{target:exV;opacity:0;visible:false}}
                    ]
                    transitions:[
                        Transition{from:"active";to:"inactive"
                            SequentialAnimation{
                                ParallelAnimation{
                                    NumberAnimation{target:exTx;property:"x";to:-60;duration:280;easing.type:Easing.InOutQuart}
                                    NumberAnimation{target:exV;property:"opacity";to:0;duration:180;easing.type:Easing.OutCubic}}
                                PropertyAction{target:exV;property:"visible";value:false}}},
                        Transition{from:"inactive";to:"active"
                            SequentialAnimation{
                                PropertyAction{target:exV;property:"visible";value:true}
                                ParallelAnimation{
                                    NumberAnimation{target:exTx;property:"x";from:40;to:0;duration:450;easing.type:Easing.OutBack;easing.overshoot:1.2}
                                    NumberAnimation{target:exV;property:"opacity";from:0;to:1;duration:300;easing.type:Easing.OutCubic}}}}
                    ]
                }

                CreateView{
                    id:crV;anchors.fill:parent;manager:mgr
                    dragActive:wD.containsDrag&&mode===1

                    transform:Translate{id:crTx;x:0}
                    opacity:1

                    states:[
                        State{name:"active";when:mode===1
                            PropertyChanges{target:crTx;x:0}
                            PropertyChanges{target:crV;opacity:1;visible:true}},
                        State{name:"inactive";when:mode!==1
                            PropertyChanges{target:crTx;x:60}
                            PropertyChanges{target:crV;opacity:0;visible:false}}
                    ]
                    transitions:[
                        Transition{from:"active";to:"inactive"
                            SequentialAnimation{
                                ParallelAnimation{
                                    NumberAnimation{target:crTx;property:"x";to:60;duration:280;easing.type:Easing.InOutQuart}
                                    NumberAnimation{target:crV;property:"opacity";to:0;duration:180;easing.type:Easing.OutCubic}}
                                PropertyAction{target:crV;property:"visible";value:false}}},
                        Transition{from:"inactive";to:"active"
                            SequentialAnimation{
                                PropertyAction{target:crV;property:"visible";value:true}
                                ParallelAnimation{
                                    NumberAnimation{target:crTx;property:"x";from:-40;to:0;duration:450;easing.type:Easing.OutBack;easing.overshoot:1.2}
                                    NumberAnimation{target:crV;property:"opacity";from:0;to:1;duration:300;easing.type:Easing.OutCubic}}}}
                    ]
                }
            }
        }
    }

    // ── Extract flow ──────────────────────────────────────
    QtObject {
        id: extractFlow
        function start() {
            if (mgr.destinationExists()) folderDlg.visible = true
            else checkFiles()
        }
        function checkFiles() {
            var c = mgr.countConflicts()
            if (c > 0) { fileDlg.count = c; fileDlg.visible = true }
            else { mgr.conflictMode = 0; mgr.extract() }
        }
    }

    FileDialog{id:elsewhereDlg;mode:"folder";title:"Extract To"
        onAccepted:{
            mgr.setDestinationFolder(selectedFile.toString())
            folderDlg.visible=false
            mgr.extract()
        }}

    // ── Step 1: Folder exists ─────────────────────────────
    Item{id:folderDlg;visible:false;anchors.fill:parent;z:200
        Rectangle{anchors.fill:parent;color:"#000000";opacity:0.4;MouseArea{anchors.fill:parent}}
        Rectangle{anchors.centerIn:parent;width:360;height:fdC.implicitHeight+48;radius:28;color:colors.surfaceContainerHigh
            ColumnLayout{id:fdC;anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;anchors.margins:28;spacing:12
                Icon{source:"folder";size:28;color:colors.primary;Layout.alignment:Qt.AlignHCenter}
                Text{text:"Folder already exists";font.family:ChiTheme.fontFamily;font.pixelSize:18;font.weight:Font.Medium;color:colors.onSurface;Layout.alignment:Qt.AlignHCenter}
                Text{text:mgr.destinationPath?mgr.destinationPath.split("/").pop():"";font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurfaceVariant;Layout.alignment:Qt.AlignHCenter}
                Item{Layout.preferredHeight:4}
                Button{Layout.fillWidth:true;text:"Extract Into Existing";variant:"filled";onClicked:{folderDlg.visible=false;extractFlow.checkFiles()}}
                Button{Layout.fillWidth:true;text:"Rename Folder";variant:"outlined";onClicked:{folderDlg.visible=false;renameFolderDlg.visible=true}}
                Button{Layout.fillWidth:true;text:"Extract Elsewhere";variant:"outlined";onClicked:{folderDlg.visible=false;elsewhereDlg.open()}}
                Button{Layout.fillWidth:true;text:"Cancel";variant:"text";onClicked:folderDlg.visible=false}}}}

    // ── Rename folder sub-dialog ──────────────────────────
    Item{id:renameFolderDlg;visible:false;anchors.fill:parent;z:200

        function applyRename(){
            if(rfInput.text.length===0)return
            var parts=mgr.destinationPath.split("/");parts.pop()
            mgr.destinationPath=parts.join("/")+"/"+rfInput.text
            renameFolderDlg.visible=false;extractFlow.start()
        }

        Rectangle{anchors.fill:parent;color:"#000000";opacity:0.4;MouseArea{anchors.fill:parent}}
        Rectangle{anchors.centerIn:parent;width:360;height:rfC.implicitHeight+48;radius:28;color:colors.surfaceContainerHigh
            ColumnLayout{id:rfC;anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;anchors.margins:28;spacing:12
                Icon{source:"edit";size:28;color:colors.primary;Layout.alignment:Qt.AlignHCenter}
                Text{text:"Rename destination folder";font.family:ChiTheme.fontFamily;font.pixelSize:18;font.weight:Font.Medium;color:colors.onSurface;Layout.alignment:Qt.AlignHCenter}
                Rectangle{Layout.fillWidth:true;height:44;radius:12;color:colors.surfaceContainerHighest
                    TextInput{id:rfInput;anchors.fill:parent;anchors.leftMargin:16;anchors.rightMargin:16;verticalAlignment:Text.AlignVCenter
                        font.family:ChiTheme.fontFamily;font.pixelSize:14;color:colors.onSurface;selectionColor:colors.primary;selectedTextColor:colors.onPrimary;clip:true
                        onAccepted:renameFolderDlg.applyRename()}}
                Item{Layout.preferredHeight:2}
                Button{Layout.fillWidth:true;variant:"filled";showIcon:true;icon:"unarchive"
                    text:"Extract as \""+rfInput.text+"\""
                    enabled:rfInput.text.length>0
                    onClicked:renameFolderDlg.applyRename()}
                Button{Layout.fillWidth:true;text:"Cancel";variant:"text";onClicked:renameFolderDlg.visible=false}}}
        onVisibleChanged:if(visible){rfInput.text=mgr.archiveBaseName+"_1";rfInput.forceActiveFocus();rfInput.selectAll()}}

    // ── Step 2: File conflicts ────────────────────────────
    Item{id:fileDlg;visible:false;anchors.fill:parent;z:200;property int count:0
        Rectangle{anchors.fill:parent;color:"#000000";opacity:0.4;MouseArea{anchors.fill:parent}}
        Rectangle{anchors.centerIn:parent;width:360;height:fcC.implicitHeight+48;radius:28;color:colors.surfaceContainerHigh
            ColumnLayout{id:fcC;anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;anchors.margins:28;spacing:12
                Icon{source:"warning";size:28;color:colors.error;Layout.alignment:Qt.AlignHCenter}
                Text{text:fileDlg.count+" file"+(fileDlg.count>1?"s":"")+" already exist";font.family:ChiTheme.fontFamily;font.pixelSize:18;font.weight:Font.Medium;color:colors.onSurface;Layout.alignment:Qt.AlignHCenter}
                Text{text:"in "+(mgr.destinationPath||"");font.family:ChiTheme.fontFamily;font.pixelSize:12;color:colors.onSurfaceVariant;elide:Text.ElideMiddle;Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter}
                Item{Layout.preferredHeight:4}
                Button{Layout.fillWidth:true;text:"Overwrite All";variant:"filled";onClicked:{mgr.conflictMode=0;mgr.extract();fileDlg.visible=false}}
                Button{Layout.fillWidth:true;text:"Skip Existing";variant:"outlined";onClicked:{mgr.conflictMode=1;mgr.extract();fileDlg.visible=false}}
                Button{Layout.fillWidth:true;text:"Auto-Rename";variant:"outlined";onClicked:{mgr.conflictMode=2;mgr.extract();fileDlg.visible=false}}
                Button{Layout.fillWidth:true;text:"Cancel";variant:"text";onClicked:fileDlg.visible=false}}}}

    // ── Settings ──────────────────────────────────────────
    Item{id:settingsDlg;visible:false;anchors.fill:parent;z:200
        Rectangle{anchors.fill:parent;color:"#000000";opacity:0.4;MouseArea{anchors.fill:parent;onClicked:settingsDlg.visible=false}}
        Rectangle{anchors.centerIn:parent;width:360;height:stC.implicitHeight+48;radius:28;color:colors.surfaceContainerHigh
            ColumnLayout{id:stC;anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;anchors.margins:28;spacing:16
                Icon{source:"settings";size:28;color:colors.primary;Layout.alignment:Qt.AlignHCenter}
                Text{text:"Settings";font.family:ChiTheme.fontFamily;font.pixelSize:22;font.weight:Font.Bold;color:colors.onSurface;Layout.alignment:Qt.AlignHCenter}
                Item{Layout.preferredHeight:4}
                RowLayout{Layout.fillWidth:true
                    ColumnLayout{Layout.fillWidth:true;spacing:2
                        Text{text:"Create parent folder";font.family:ChiTheme.fontFamily;font.pixelSize:14;font.weight:Font.Medium;color:colors.onSurface}
                        Text{text:"Extract into a folder named after the archive";font.family:ChiTheme.fontFamily;font.pixelSize:12;color:colors.onSurfaceVariant;wrapMode:Text.WordWrap;Layout.fillWidth:true}}
                    Switch{checked:mgr.createParentFolder;onCheckedChanged:mgr.createParentFolder=checked}}
                RowLayout{Layout.fillWidth:true
                    ColumnLayout{Layout.fillWidth:true;spacing:2
                        Text{text:"Dark mode";font.family:ChiTheme.fontFamily;font.pixelSize:14;font.weight:Font.Medium;color:colors.onSurface}
                        Text{text:"Use dark color scheme";font.family:ChiTheme.fontFamily;font.pixelSize:12;color:colors.onSurfaceVariant}}
                    Switch{checked:ChiTheme.isDarkMode;onCheckedChanged:ChiTheme.setDarkMode(checked)}}
                Item{Layout.preferredHeight:4}
                Button{text:"Close";variant:"text";Layout.alignment:Qt.AlignHCenter;onClicked:settingsDlg.visible=false}}}}

    // ── About ─────────────────────────────────────────────
    Item{id:aboutDlg;visible:false;anchors.fill:parent;z:200
        Rectangle{anchors.fill:parent;color:"#000000";opacity:0.4;MouseArea{anchors.fill:parent;onClicked:aboutDlg.visible=false}}
        Rectangle{anchors.centerIn:parent;width:300;height:abC.implicitHeight+48;radius:28;color:colors.surfaceContainerHigh
            ColumnLayout{id:abC;anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;anchors.margins:28;spacing:10
                Icon{source:"folder_zip";size:40;color:colors.primary;Layout.alignment:Qt.AlignHCenter}
                Text{text:"ChiExtract";font.family:ChiTheme.fontFamily;font.pixelSize:22;font.weight:Font.Bold;color:colors.onSurface;Layout.alignment:Qt.AlignHCenter}
                Text{text:"Version 1.0.0";font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurfaceVariant;Layout.alignment:Qt.AlignHCenter}
                Text{text:"Powered by libarchive · Built with Chi";font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurfaceVariant;Layout.alignment:Qt.AlignHCenter;wrapMode:Text.WordWrap;Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter}
                Item{Layout.preferredHeight:4}
                Button{text:"Close";variant:"text";Layout.alignment:Qt.AlignHCenter;onClicked:aboutDlg.visible=false}}}}

    Item{anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter;width:Math.min(parent.width-48,480);height:80;z:100
        Snackbar{id:snack;position:"bottom";onActionClicked:Qt.openUrlExternally("file://"+mgr.destinationPath)}}
    Connections{target:mgr
        function onExtractionComplete(){snack.show("Extraction complete","Open Folder")}
        function onCreationComplete(){snack.show("Archive created")}
        function onErrorChanged(){if(mgr.errorMessage)snack.show(mgr.errorMessage)}}
}
