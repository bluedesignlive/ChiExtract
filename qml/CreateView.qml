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

    // ── Overwrite dialog with rename ──────────────────────
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
        Rectangle{Layout.fillWidth:true;Layout.preferredHeight:!hasFiles?140:68;radius:20;color:"transparent"
            border.width:1.5;border.color:dragActive?colors.primary:colors.outlineVariant
            Behavior on Layout.preferredHeight{NumberAnimation{duration:250;easing.type:Easing.OutCubic}}
            Behavior on border.color{ColorAnimation{duration:150}}
            Rectangle{anchors.fill:parent;radius:parent.radius;color:colors.primary;opacity:dragActive?0.08:0;Behavior on opacity{NumberAnimation{duration:150}}}
            MouseArea{anchors.fill:parent;enabled:!manager.busy;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:addDlg.open()}
            ColumnLayout{anchors.centerIn:parent;spacing:8;visible:!hasFiles
                Icon{source:"note_add";size:36;color:colors.onSurfaceVariant;Layout.alignment:Qt.AlignHCenter}
                Text{text:"Drop files here or click to browse";font.family:ChiTheme.fontFamily;font.pixelSize:15;font.weight:Font.Medium;color:colors.onSurface;Layout.alignment:Qt.AlignHCenter}}
            RowLayout{anchors.fill:parent;anchors.margins:14;spacing:12;visible:hasFiles
                Icon{source:"inventory_2";size:28;color:colors.onSurfaceVariant}
                ColumnLayout{Layout.fillWidth:true;spacing:2
                    Text{text:manager.createFiles.length+(manager.createFiles.length===1?" item":" items");font.family:ChiTheme.fontFamily;font.pixelSize:14;font.weight:Font.Medium;color:colors.onSurface}
                    Text{text:manager.createFilesSize+" total";font.family:ChiTheme.fontFamily;font.pixelSize:12;color:colors.onSurfaceVariant}}}}

        RowLayout{Layout.fillWidth:true;spacing:10;visible:!manager.busy&&!isCreated
            Button{Layout.fillWidth:true;text:"Add Files";variant:"tonal";showIcon:true;icon:"add";onClicked:addDlg.open()}
            Button{Layout.fillWidth:true;text:"Add Folder";variant:"tonal";showIcon:true;icon:"create_new_folder";onClicked:folderDlg.open()}}

        LinearProgressIndicator{Layout.fillWidth:true;visible:isCreating
            progress:manager.progress>=0?manager.progress:0;indeterminate:manager.progress<0}

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

        RowLayout{Layout.fillWidth:true;spacing:12
            Button{visible:canCreate;Layout.fillWidth:true;text:"Create Archive";variant:"filled";showIcon:true;icon:"archive";onClicked:saveDlg.open()}
            Button{visible:isCreating;Layout.fillWidth:true;text:"Cancel";variant:"outlined";onClicked:manager.cancel()}
            Button{visible:isCreated;Layout.fillWidth:true;text:"Create Another";variant:"filled";onClicked:manager.clearFiles()}
            Button{visible:hasError;Layout.fillWidth:true;text:"Try Again";variant:"filled";onClicked:manager.clearFiles()}
            Button{visible:hasFiles&&!manager.busy&&!isCreated;text:"Clear";variant:"text";onClicked:manager.clearFiles()}}
    }
}
