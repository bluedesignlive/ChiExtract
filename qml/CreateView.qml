import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as QC
import Chi
import ChiExtract.Backend 1.0

Item {
    id: root
    property var manager: null
    property bool dragActive: false
    property var colors: ChiTheme.colors

    readonly property var formats: manager?manager.supportedFormats():[]
    property int formatIndex: 0
    property string outputName: "archive"

    readonly property bool isOwnOp: manager && manager.operationType === 2
    readonly property bool isCreating: isOwnOp && manager.busy
    readonly property bool isCreated: isOwnOp && !manager.busy && manager.status === "created"
    readonly property bool hasError: isOwnOp && !manager.busy && (manager.status==="error"||manager.status==="cancelled")
    readonly property bool hasFiles: manager && manager.createFiles.length > 0
    readonly property bool canCreate: hasFiles && !manager.busy && !isCreated

    property string _pendingDir: ""

    function openAddFiles(){addDlg.open()}

    readonly property string createInfoText: {
        if(!hasFiles) return ""
        if(isCreating) return Math.round(manager.progress*100)+"% — "+(manager.currentEntry||"")
        if(isCreated) return "Archive created"
        if(hasError) return manager.status==="error"?(manager.errorMessage||"Error"):"Cancelled"
        return manager.createFiles.length+(manager.createFiles.length===1?" item":" items")+" · "+manager.createFilesSize
    }

    FileDialog{id:addDlg;mode:"openMultiple";title:"Add Files"
        onAccepted:{var p=[];for(var i=0;i<selectedFiles.length;i++)p.push(selectedFiles[i].toString());manager.addFiles(p)}}
    FileDialog{id:folderDlg;mode:"folder";title:"Add Folder";onAccepted:manager.addFiles([selectedFile.toString()])}
    FileDialog{id:saveDlg;mode:"folder";title:"Save Archive To"
        onAccepted:{var dir=selectedFile.toString().replace("file://","");root._pendingDir=dir;_tryCreate()}}

    function _tryCreate(){
        var ext=formats[formatIndex]||"tar.gz"
        var full=_pendingDir+"/"+outputName+"."+ext
        if(manager.fileExists(full)){owDlg.archivePath=full;owDlg.visible=true}
        else manager.createArchive(full,ext)
    }

    // ── Overwrite dialog ──────────────────────────────────
    Item{id:owDlg;visible:false;anchors.fill:parent;z:200;property string archivePath:""
        Rectangle{anchors.fill:parent;color:"#000000";opacity:0.4;MouseArea{anchors.fill:parent}}
        Rectangle{anchors.centerIn:parent;width:360;height:owC.implicitHeight+48;radius:28;color:colors.surfaceContainerHigh
            ColumnLayout{id:owC;anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;anchors.margins:28;spacing:12
                Text{text:"Archive already exists";font.family:ChiTheme.fontFamily;font.pixelSize:18;font.weight:Font.Medium;color:colors.onSurface;Layout.alignment:Qt.AlignHCenter}
                Text{text:owDlg.archivePath.split("/").pop();font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurfaceVariant;elide:Text.ElideMiddle;Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter}
                Item{Layout.preferredHeight:2}
                Text{text:"Rename:";font.family:ChiTheme.fontFamily;font.pixelSize:12;color:colors.onSurfaceVariant}
                Rectangle{Layout.fillWidth:true;height:40;radius:12;color:colors.surfaceContainerHighest
                    RowLayout{anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:14;spacing:4
                        TextInput{id:renameInput;Layout.fillWidth:true;verticalAlignment:Text.AlignVCenter
                            font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurface
                            selectionColor:colors.primary;selectedTextColor:colors.onPrimary;clip:true}
                        Text{text:"."+(formats[formatIndex]||"tar.gz");font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurfaceVariant}}}
                Item{Layout.preferredHeight:2}
                Button{Layout.fillWidth:true;text:"Save as \""+renameInput.text+"\"";variant:"filled";enabled:renameInput.text.length>0&&renameInput.text!==outputName
                    onClicked:{var ext=formats[formatIndex]||"tar.gz";manager.createArchive(root._pendingDir+"/"+renameInput.text+"."+ext,ext);owDlg.visible=false}}
                Button{Layout.fillWidth:true;text:"Overwrite";variant:"outlined"
                    onClicked:{var ext=formats[formatIndex]||"tar.gz";manager.createArchive(owDlg.archivePath,ext);owDlg.visible=false}}
                Button{Layout.fillWidth:true;text:"Cancel";variant:"text";onClicked:owDlg.visible=false}}
        }
        onVisibleChanged:if(visible)renameInput.text=outputName+"_1"
    }

    ColumnLayout{anchors.fill:parent;spacing:16

        // Drop zone / status box
        Rectangle{Layout.fillWidth:true;Layout.preferredHeight:!hasFiles?140:68;radius:20;color:"transparent"
            border.width:1.5;border.color:dragActive?colors.primary:colors.outlineVariant
            Behavior on Layout.preferredHeight{NumberAnimation{duration:250;easing.type:Easing.OutCubic}}
            Behavior on border.color{ColorAnimation{duration:150}}
            Rectangle{anchors.fill:parent;radius:parent.radius;color:colors.primary;opacity:dragActive?0.08:0;Behavior on opacity{NumberAnimation{duration:150}}}
            MouseArea{anchors.fill:parent;enabled:!manager.busy&&!isCreated;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:addDlg.open()}

            ColumnLayout{anchors.centerIn:parent;spacing:8;visible:!hasFiles
                Icon{source:"note_add";size:36;color:colors.onSurfaceVariant;Layout.alignment:Qt.AlignHCenter}
                Text{text:"Drop files here or click to browse";font.family:ChiTheme.fontFamily;font.pixelSize:15;font.weight:Font.Medium;color:colors.onSurface;Layout.alignment:Qt.AlignHCenter}}

            RowLayout{anchors.fill:parent;anchors.margins:14;spacing:12;visible:hasFiles
                Icon{size:28;Layout.alignment:Qt.AlignVCenter
                    source:hasError?"error":isCreated?"check_circle":isCreating?"hourglass_empty":"inventory_2"
                    color:hasError?colors.error:isCreated?colors.primary:colors.onSurfaceVariant}
                ColumnLayout{Layout.fillWidth:true;spacing:2
                    Text{text:isCreated?"Archive created":isCreating?"Creating…":manager.createFiles.length+(manager.createFiles.length===1?" item":" items")
                        font.family:ChiTheme.fontFamily;font.pixelSize:14;font.weight:Font.Medium;color:colors.onSurface}
                    Text{text:createInfoText;font.family:ChiTheme.fontFamily;font.pixelSize:12
                        color:hasError?colors.error:colors.onSurfaceVariant;elide:Text.ElideRight;Layout.fillWidth:true}}
                IconButton{icon:"close";variant:"standard";size:"small";visible:hasFiles&&!manager.busy&&!isCreated;onClicked:manager.clearFiles()}}}

        // Add buttons — right-aligned
        RowLayout{Layout.fillWidth:true;spacing:10;visible:!manager.busy&&!isCreated&&hasFiles
            Item{Layout.fillWidth:true}
            Button{text:"Add Files";variant:"tonal";showIcon:true;icon:"add";onClicked:addDlg.open()}
            Button{text:"Add Folder";variant:"tonal";showIcon:true;icon:"create_new_folder";onClicked:folderDlg.open()}}

        LinearProgressIndicator{Layout.fillWidth:true;visible:isCreating
            progress:manager.progress>=0?manager.progress:0;indeterminate:manager.progress<0}

        // File list
        Rectangle{Layout.fillWidth:true;Layout.fillHeight:true;radius:14;clip:true;color:colors.surfaceContainerHigh;visible:hasFiles
            ListView{id:cl;anchors.fill:parent;anchors.margins:6;model:manager.createFiles;boundsBehavior:Flickable.StopAtBounds;spacing:1
                QC.ScrollBar.vertical:QC.ScrollBar{policy:QC.ScrollBar.AsNeeded}
                delegate:Rectangle{width:cl.width;height:36;radius:8;color:cH.containsMouse?Qt.rgba(colors.onSurface.r,colors.onSurface.g,colors.onSurface.b,0.04):"transparent"
                    MouseArea{id:cH;anchors.fill:parent;hoverEnabled:true}
                    RowLayout{anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:6;spacing:10
                        Icon{source:manager.isDirectory(modelData)?"folder":"description";size:16;color:manager.isDirectory(modelData)?colors.primary:colors.onSurfaceVariant}
                        Text{text:manager.fileName(modelData);font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurface;elide:Text.ElideMiddle;Layout.fillWidth:true}
                        Text{text:manager.fileSize(modelData);font.family:ChiTheme.fontFamily;font.pixelSize:11;color:colors.onSurfaceVariant}
                        IconButton{icon:"close";variant:"standard";size:"xsmall";visible:!manager.busy;onClicked:manager.removeFile(index)}}}}}

        Item{Layout.fillHeight:true;visible:!hasFiles}

        // Archive settings
        ColumnLayout{Layout.fillWidth:true;spacing:10;visible:canCreate
            RowLayout{Layout.fillWidth:true;spacing:14
                Text{text:"Name:";font.family:ChiTheme.fontFamily;font.pixelSize:12;color:colors.onSurfaceVariant;Layout.alignment:Qt.AlignVCenter}
                Rectangle{Layout.fillWidth:true;height:38;radius:12;color:colors.surfaceContainerHighest
                    TextInput{anchors.left:parent.left;anchors.right:eL.left;anchors.leftMargin:14;anchors.rightMargin:4;anchors.verticalCenter:parent.verticalCenter
                        text:outputName;onTextChanged:outputName=text;font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurface
                        selectionColor:colors.primary;selectedTextColor:colors.onPrimary;clip:true}
                    Text{id:eL;anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter
                        text:"."+(formats[formatIndex]||"tar.gz");font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurfaceVariant}}}
            RowLayout{Layout.fillWidth:true;spacing:14
                Text{text:"Format:";font.family:ChiTheme.fontFamily;font.pixelSize:12;color:colors.onSurfaceVariant;Layout.alignment:Qt.AlignVCenter}
                SegmentedButton{size:"small";segments:{var s=[];for(var i=0;i<formats.length;i++)s.push({text:formats[i]});return s}
                    selectedIndex:formatIndex;onSelectionChanged:function(i){formatIndex=i[0]}}}}

        Item{Layout.preferredHeight:4}

        // Actions — right-aligned, natural width
        RowLayout{Layout.fillWidth:true;spacing:12
            Item{Layout.fillWidth:true}
            Button{visible:hasFiles&&!manager.busy&&!isCreated;text:"Clear";variant:"text";onClicked:manager.clearFiles()}
            Button{visible:isCreating;text:"Cancel";variant:"outlined";onClicked:manager.cancel()}
            Button{visible:hasError;text:"Try Again";variant:"filled";onClicked:manager.clearFiles()}
            Button{visible:isCreated;text:"Create Another";variant:"filled";onClicked:manager.clearFiles()}
            Button{visible:canCreate;text:"Create Archive";variant:"filled";showIcon:true;icon:"archive";onClicked:saveDlg.open()}}
    }
}
