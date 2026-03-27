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
    signal extractRequested()

    readonly property bool hasArchive: manager && (manager.archivePath||"") !== ""
    readonly property bool isOwnOp: manager && manager.operationType === 1
    readonly property bool isExtracting: hasArchive && isOwnOp && manager.status === "extracting"
    readonly property bool isComplete: hasArchive && isOwnOp && manager.status === "extracted"
    readonly property bool hasError: hasArchive && isOwnOp && (manager.status==="error"||manager.status==="cancelled")
    readonly property bool canExtract: hasArchive && !manager.busy && manager.status === "loaded"
    readonly property bool showList: hasArchive && manager.contents && (manager.contents.fileCount+manager.contents.dirCount)>0

    readonly property string infoText: {
        if(!hasArchive) return ""
        if(isExtracting) return Math.round(manager.progress*100)+"% — "+(manager.currentEntry||"")
        if(isComplete) return "Extraction complete"
        if(hasError) return manager.status==="error"?(manager.errorMessage||"Error"):"Cancelled"
        if(manager.status==="loading") return "Reading contents…"
        var p=[]
        if(manager.archiveSize)p.push(manager.archiveSize);if(manager.archiveType)p.push(manager.archiveType)
        var fc=manager.contents?manager.contents.fileCount:0,dc=manager.contents?manager.contents.dirCount:0
        if(fc)p.push(fc+(fc===1?" file":" files"));if(dc)p.push(dc+(dc===1?" folder":" folders"))
        return p.join(" · ")
    }

    function openFileBrowser(){openDlg.open()}
    function changeDestinationThenExtract(){destDlg.reextract=true;destDlg.open()}

    FileDialog{id:openDlg;mode:"open";title:"Open Archive"
        nameFilters:["Archives (*.zip *.tar *.tar.gz *.tgz *.tar.bz2 *.tbz2 *.tar.xz *.txz *.7z *.rar *.gz *.bz2 *.xz *.zst *.iso *.cpio *.deb *.rpm)","All Files (*)"]
        onAccepted:manager.openArchive(selectedFile.toString())}
    FileDialog{id:destDlg;mode:"folder";title:"Extract To";property bool reextract:false
        onAccepted:{manager.setDestinationFolder(selectedFile.toString());if(reextract){reextract=false;root.extractRequested()}}
        onRejected:reextract=false}

    ColumnLayout{anchors.fill:parent;spacing:16
        Rectangle{Layout.fillWidth:true;Layout.preferredHeight:!hasArchive?160:80;radius:20;color:"transparent"
            border.width:1.5;border.color:dragActive?colors.primary:colors.outlineVariant
            Behavior on Layout.preferredHeight{NumberAnimation{duration:250;easing.type:Easing.OutCubic}}
            Behavior on border.color{ColorAnimation{duration:150}}
            Rectangle{anchors.fill:parent;radius:parent.radius;color:colors.primary;opacity:dragActive?0.08:0;Behavior on opacity{NumberAnimation{duration:150}}}
            MouseArea{anchors.fill:parent;enabled:!manager.busy;hoverEnabled:true;cursorShape:Qt.PointingHandCursor
                onClicked:{if(isComplete||hasError)manager.clear();openDlg.open()}}
            ColumnLayout{anchors.centerIn:parent;spacing:10;visible:!hasArchive
                Icon{source:"unarchive";size:40;color:colors.onSurfaceVariant;Layout.alignment:Qt.AlignHCenter}
                Text{text:"Drop archive here or click to browse";font.family:ChiTheme.fontFamily;font.pixelSize:15;font.weight:Font.Medium;color:colors.onSurface;Layout.alignment:Qt.AlignHCenter}}
            RowLayout{anchors.fill:parent;anchors.margins:16;spacing:14;visible:hasArchive
                Icon{size:32;Layout.alignment:Qt.AlignVCenter
                    source:hasError?"error":isComplete?"check_circle":manager.status==="loading"?"hourglass_empty":"folder_zip"
                    color:hasError?colors.error:isComplete?colors.primary:colors.onSurfaceVariant}
                ColumnLayout{Layout.fillWidth:true;spacing:2
                    Text{text:manager.archiveName||"";font.family:ChiTheme.fontFamily;font.pixelSize:14;font.weight:Font.Medium;color:colors.onSurface;elide:Text.ElideMiddle;Layout.fillWidth:true}
                    Text{text:infoText;font.family:ChiTheme.fontFamily;font.pixelSize:12;color:hasError?colors.error:colors.onSurfaceVariant;elide:Text.ElideRight;Layout.fillWidth:true}}
                IconButton{icon:"close";variant:"standard";size:"small";visible:!manager.busy;onClicked:manager.clear()}}}

        LinearProgressIndicator{Layout.fillWidth:true;visible:isExtracting||manager.status==="loading"
            progress:manager.progress>=0?manager.progress:0;indeterminate:manager.progress<0||manager.status==="loading"}

        Rectangle{Layout.fillWidth:true;Layout.fillHeight:true;radius:14;clip:true;color:colors.surfaceContainerHigh;visible:showList
            ListView{id:fl;anchors.fill:parent;anchors.margins:6;model:manager.contents;boundsBehavior:Flickable.StopAtBounds;spacing:1
                QC.ScrollBar.vertical:QC.ScrollBar{policy:QC.ScrollBar.AsNeeded}
                delegate:Rectangle{width:fl.width;height:34;radius:8;color:fH.containsMouse?Qt.rgba(colors.onSurface.r,colors.onSurface.g,colors.onSurface.b,0.04):"transparent"
                    MouseArea{id:fH;anchors.fill:parent;hoverEnabled:true}
                    RowLayout{anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:14;spacing:10
                        Icon{source:model.isDir?"folder":"description";size:16;color:model.isDir?colors.primary:colors.onSurfaceVariant}
                        Text{text:model.fileName;font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurface;elide:Text.ElideMiddle;Layout.fillWidth:true}
                        Text{visible:!model.isDir&&model.fileSize>0;text:manager.formatBytes(model.fileSize);font.family:ChiTheme.fontFamily;font.pixelSize:11;color:colors.onSurfaceVariant}}}}}

        Item{Layout.fillHeight:true;visible:!showList}

        ColumnLayout{Layout.fillWidth:true;spacing:8;visible:canExtract
            Text{text:"Extract to";font.family:ChiTheme.fontFamily;font.pixelSize:12;color:colors.onSurfaceVariant}
            RowLayout{Layout.fillWidth:true;spacing:10
                Rectangle{Layout.fillWidth:true;height:40;radius:12;color:colors.surfaceContainerHighest
                    Text{anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:14;verticalAlignment:Text.AlignVCenter
                        text:manager.destinationPath||"";font.family:ChiTheme.fontFamily;font.pixelSize:13;color:colors.onSurface;elide:Text.ElideMiddle}}
                IconButton{icon:"folder_open";variant:"standard";size:"small";onClicked:{destDlg.reextract=false;destDlg.open()}}}}

        Item{Layout.preferredHeight:4}

        RowLayout{Layout.fillWidth:true;spacing:12
            Button{visible:canExtract;Layout.fillWidth:true;text:"Extract";variant:"filled";showIcon:true;icon:"unarchive";onClicked:extractRequested()}
            Button{visible:isExtracting;Layout.fillWidth:true;text:"Cancel";variant:"outlined";onClicked:manager.cancel()}
            Button{visible:isComplete;Layout.fillWidth:true;text:"Open Folder";variant:"outlined";showIcon:true;icon:"folder_open";onClicked:Qt.openUrlExternally("file://"+manager.destinationPath)}
            Button{visible:isComplete;Layout.fillWidth:true;text:"Extract Another";variant:"filled";showIcon:true;icon:"unarchive";onClicked:manager.clear()}
            Button{visible:hasError;Layout.fillWidth:true;text:"Try Again";variant:"filled";onClicked:manager.clear()}}
        Item{Layout.preferredHeight:2}
        Text{visible:!hasArchive;text:"ZIP · TAR · GZ · BZ2 · XZ · 7Z · RAR · ISO · DEB · RPM";font.family:ChiTheme.fontFamily;font.pixelSize:11;color:colors.outline;Layout.alignment:Qt.AlignHCenter}}
}
