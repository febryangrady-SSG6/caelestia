import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Caelestia.Services
import "components"

FocusScope {
    id: root

    width: 1920
    height: 1080
    focus: true

    readonly property real lockHeight: Math.min(width, height)
    readonly property real lockLong: lockHeight * 0.7 * (16.0 / 9.0)
    readonly property real lockShort: lockHeight * 0.7
    readonly property real centerScale: Math.max(0.65, lockHeight / 1080)
    readonly property real centerWidth: 400 * centerScale
    readonly property real passwordPillWidth: 300 * centerScale
    readonly property bool isPortrait: height > width * 1.2

    readonly property bool use12h: (typeof config !== "undefined" && config.use12h !== undefined)
        ? (config.use12h === "true" || config.use12h === true)
        : (Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("a") !== -1)
    readonly property bool isCaelestiaMode: (typeof config !== "undefined" && config.caelestiaMode !== undefined)
        ? (config.caelestiaMode === "true" || config.caelestiaMode === true)
        : true
    readonly property bool recolourLogo: (typeof config !== "undefined" && config.recolourLogo !== undefined)
        ? (config.recolourLogo === "true" || config.recolourLogo === true)
        : true
    readonly property int profilePicShape: (typeof config !== "undefined" && config.profilePicShape !== undefined)
        ? parseInt(config.profilePicShape)
        : 13
    readonly property bool rotateProfilePic: (typeof config !== "undefined" && config.rotateProfilePic !== undefined)
        ? (config.rotateProfilePic === "true" || config.rotateProfilePic === true)
        : false
    readonly property bool blurWallpaper: (typeof config !== "undefined" && config.blurWallpaper !== undefined)
        ? (config.blurWallpaper === "true" || config.blurWallpaper === true)
        : false

    readonly property real bgRadius: 42 * (lockHeight / 1080)
    readonly property real bgMargin: 16 * (lockHeight / 1080)
    readonly property real cardRadius: bgRadius - bgMargin

    function cfgColor(key, fallback) {
        if (typeof config !== "undefined" && config[key] !== undefined && config[key].toString().length > 0)
            return config[key].toString();
        return fallback;
    }

    readonly property color clSurface: cfgColor("clSurface", "#131313")
    readonly property color clSurfaceFg: cfgColor("clSurfaceFg", "#e4e4e4")
    readonly property color clSurfaceContainer: cfgColor("clSurfaceContainer", "#1c1c1c")
    readonly property color clSurfaceContainerHigh: cfgColor("clSurfaceContainerHigh", "#252525")
    readonly property color clSurfaceContainerHighest: cfgColor("clSurfaceContainerHighest", "#303030")
    readonly property color clPrimary: cfgColor("clPrimary", "#c8c8c8")
    readonly property color clSecondary: cfgColor("clSecondary", "#b0b0b0")
    readonly property color clPrimaryFg: cfgColor("clPrimaryFg", "#1a1a1a")
    readonly property color clError: cfgColor("clError", "#ffb4ab")
    readonly property color clSurfaceVariantFg: cfgColor("clSurfaceVariantFg", "#a0a0a0")
    readonly property color clPrimaryContainer: cfgColor("clPrimaryContainer", "#383838")
    readonly property color clSecondaryContainer: cfgColor("clSecondaryContainer", "#2c2c2c")
    readonly property color clTertiary: cfgColor("clTertiary", "#d6d6d6")
    readonly property color clOnTertiary: cfgColor("clOnTertiary", "#242424")
    readonly property color clOutline: cfgColor("clOutline", "#707070")

    readonly property color clCardBg: alterColour(clSurfaceContainer, 0.60, 1)
    readonly property color clCardBgHigh: alterColour(clSurfaceContainerHigh, 0.60, 1)

    readonly property var clTerms: ["#202020", "#3a3a3a", "#545454", "#6e6e6e", "#888888", "#a4a4a4", "#c2c2c2", "#e0e0e0"]

    property bool ready: false
    property bool isAuthenticating: false
    property string authMessage: ""
    property date currentTime: new Date()
    property string sysOsName: "Arch Linux"
    property string sysUptime: "0 mins"

    readonly property var activePasswordPill: isPortrait ? portraitPasswordPill : passwordPill
    readonly property string currentUserName: userPicker.displayText.length > 0 ? userPicker.displayText : "darkmattz"
    readonly property string currentSessionName: sessionPicker.displayText.length > 0 ? sessionPicker.displayText : "KDE"

    readonly property int liveCpu: Math.round((Cpu.percentage ?? 0) * 100)
    readonly property int liveTemp: Math.round(Cpu.temperature ?? 0)
    readonly property int liveRam: Math.round((Memory.percentage ?? 0) * 100)
    readonly property int liveDisk: Math.round((Storage.percentage ?? 0) * 100)

    property var greetingInfo: getGreeting()

    readonly property var fetchInfo: ({
        os: root.sysOsName,
        wm: root.currentSessionName,
        user: root.currentUserName,
        uptime: root.sysUptime,
        logoPath: Qt.resolvedUrl("assets/distro-logo.svg").toString()
    })

    function getLuminance(c) {
        if (!c || (c.r === 0 && c.g === 0 && c.b === 0)) return 0;
        return Math.sqrt(0.299 * (c.r * c.r) + 0.587 * (c.g * c.g) + 0.114 * (c.b * c.b));
    }

    function alterColour(c, a, layer) {
        if (!c) return Qt.rgba(0.15, 0.15, 0.15, a);
        var luminance = getLuminance(c);
        if (luminance === 0) return Qt.rgba(0.12, 0.12, 0.12, a);
        var offset = 0.3 * (1 - 0.7) * 1.5;
        var scale = (luminance + offset) / luminance;
        var r = Math.max(0, Math.min(1, c.r * scale));
        var g = Math.max(0, Math.min(1, c.g * scale));
        var b = Math.max(0, Math.min(1, c.b * scale));
        return Qt.rgba(r, g, b, a);
    }

    function getGreeting() {
        var hour = root.currentTime.getHours();
        if (hour >= 5 && hour < 12) return { greeting: qsTr("Good morning"), icon: "sunny", iconColor: root.clPrimary };
        if (hour >= 12 && hour < 17) return { greeting: qsTr("Good afternoon"), icon: "light_mode", iconColor: root.clPrimary };
        if (hour >= 17 && hour < 22) return { greeting: qsTr("Good evening"), icon: "routine", iconColor: root.clSecondary };
        return { greeting: qsTr("Good night"), icon: "bedtime", iconColor: root.clPrimary };
    }

    function readTextFile(url, callback) {
        try {
            var xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0)) {
                    if (xhr.responseText && xhr.responseText.length > 0)
                        callback(xhr.responseText);
                }
            };
            xhr.open("GET", url, true);
            xhr.send();
        } catch (e) {}
    }

    function refreshSystemInfo() {
        readTextFile("file:///etc/os-release", function(txt) {
            var lines = txt.split("\n");
            var pretty = "";
            var name = "";
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line.startsWith("PRETTY_NAME="))
                    pretty = line.slice(12).replace(/^"|"$/g, "");
                else if (line.startsWith("NAME="))
                    name = line.slice(5).replace(/^"|"$/g, "");
            }
            if (pretty.length > 0) root.sysOsName = pretty;
            else if (name.length > 0) root.sysOsName = name;
        });

        readTextFile("file:///proc/uptime", function(txt) {
            var secs = parseFloat(txt.trim().split(/\s+/)[0]);
            if (!isNaN(secs)) {
                var s = Math.floor(secs);
                var h = Math.floor(s / 3600);
                var m = Math.floor((s % 3600) / 60);
                root.sysUptime = (h > 0 ? (h + " hours, ") : "") + m + " mins";
            }
        });
    }

    function startLogin(pass) {
        if (root.isAuthenticating) return;
        msgExitAnim.stop();
        msgAppearAnim.stop();
        msgFlashAnim.stop();
        errorText.visible = false;
        portraitErrorText.visible = false;
        errorText.opacity = 0;
        portraitErrorText.opacity = 0;
        root.authMessage = "";
        root.isAuthenticating = true;
        if (typeof sddm !== "undefined")
            sddm.login(root.currentUserName, pass, sessionPicker.currentIndex);
    }

    function cycleUser() {
        if (userPicker.count > 1)
            userPicker.currentIndex = (userPicker.currentIndex + 1) % userPicker.count;
    }

    function cycleSession() {
        if (sessionPicker.count > 1)
            sessionPicker.currentIndex = (sessionPicker.currentIndex + 1) % sessionPicker.count;
    }

    ServiceRef { service: Cpu }
    ServiceRef { service: Memory }
    ServiceRef { service: Storage }
    ServiceRef { service: Weather }

    ComboBox {
        id: userPicker
        visible: false
        model: typeof userModel !== "undefined" ? userModel : null
        currentIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
        textRole: "name"
    }

    ComboBox {
        id: sessionPicker
        visible: false
        model: typeof sessionModel !== "undefined" ? sessionModel : null
        currentIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
        textRole: "name"
    }

    Timer {
        interval: 50
        running: true
        onTriggered: {
            root.ready = true;
            if (root.activePasswordPill) root.activePasswordPill.focusInput();
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date();
            var prevHour = root.currentTime.getHours();
            root.currentTime = now;
            if (now.getHours() !== prevHour)
                root.greetingInfo = root.getGreeting();
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshSystemInfo()
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null

        function onLoginFailed() {
            root.isAuthenticating = false;
            root.authMessage = qsTr("Authentication failed");
            if (passwordPill) {
                passwordPill.clearPassword();
                passwordPill.shake();
            }
            if (portraitPasswordPill) {
                portraitPasswordPill.clearPassword();
                portraitPasswordPill.shake();
            }
            msgAppearAnim.restart();
        }

        function onLoginSucceeded() {
            root.isAuthenticating = false;
        }

        function onInformationMessage(message) {
            if (message && message.length > 0) {
                root.authMessage = message;
                msgAppearAnim.restart();
            }
        }
    }

    SequentialAnimation {
        id: msgAppearAnim
        onFinished: msgFlashAnim.start()

        PropertyAction { target: errorText; property: "visible"; value: true }
        PropertyAction { target: portraitErrorText; property: "visible"; value: true }

        ParallelAnimation {
            NumberAnimation { target: errorText; property: "scale"; from: 0.7; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: errorText; property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: portraitErrorText; property: "scale"; from: 0.7; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: portraitErrorText; property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: msgFlashAnim
        loops: 2

        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation { target: errorText; property: "opacity"; to: 0.3; duration: 150 }
                NumberAnimation { target: errorText; property: "opacity"; to: 1; duration: 150 }
            }
            SequentialAnimation {
                NumberAnimation { target: portraitErrorText; property: "opacity"; to: 0.3; duration: 150 }
                NumberAnimation { target: portraitErrorText; property: "opacity"; to: 1; duration: 150 }
            }
        }
    }

    SequentialAnimation {
        id: msgExitAnim
        onFinished: root.authMessage = ""

        ParallelAnimation {
            NumberAnimation { target: errorText; property: "scale"; to: 0.7; duration: 400; easing.type: Easing.InOutQuad }
            NumberAnimation { target: errorText; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InOutQuad }
            NumberAnimation { target: portraitErrorText; property: "scale"; to: 0.7; duration: 400; easing.type: Easing.InOutQuad }
            NumberAnimation { target: portraitErrorText; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InOutQuad }
        }

        PropertyAction { target: errorText; property: "visible"; value: false }
        PropertyAction { target: portraitErrorText; property: "visible"; value: false }
    }

    Rectangle {
        anchors.fill: parent
        color: root.clSurface
    }

    Image {
        id: wallpaperBg
        anchors.fill: parent
        source: (typeof config !== "undefined" && config.background) ? config.background : "assets/background"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    MultiEffect {
        id: wallpaperBlur
        anchors.fill: wallpaperBg
        source: wallpaperBg
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        autoPaddingEnabled: false
        visible: false
    }

    Item {
        anchors.fill: parent
        visible: root.blurWallpaper
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: wallpaperBlur
            live: true
        }
    }

    FocusScope {
        id: lockScreenRoot
        anchors.fill: parent
        focus: true
        opacity: root.ready ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        Keys.onPressed: event => {
            if (root.activePasswordPill) root.activePasswordPill.focusInput();
            event.accepted = false;
        }
        Keys.onEscapePressed: {
            if (passwordPill) passwordPill.clearPassword();
            if (portraitPasswordPill) portraitPasswordPill.clearPassword();
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            onPressed: mouse => {
                if (root.activePasswordPill) root.activePasswordPill.focusInput();
                mouse.accepted = false;
            }
        }

        Item {
            Timer {
                property int n: 0
                interval: 300
                repeat: true
                running: true
                onTriggered: {
                    if (root.activePasswordPill) root.activePasswordPill.focusInput();
                    if (++n >= 10) repeat = false;
                }
            }
        }

        Item {
            id: landscapeContent

            readonly property real innerHeight: height - 2 * root.bgMargin
            readonly property real colSpacing: 16 * root.centerScale
            readonly property real leftCardPool: innerHeight - 2 * colSpacing
            readonly property real rightCardPool: innerHeight - 1 * colSpacing

            readonly property real centerSpacing: innerHeight >= 680
                ? Math.round(18 * root.centerScale)
                : (innerHeight >= 560 ? Math.round(10 * root.centerScale) : Math.max(6, Math.round(8 * root.centerScale)))
            readonly property real avatarHeightRatio: innerHeight >= 680 ? 0.36 : (innerHeight >= 560 ? 0.30 : 0.24)
            readonly property real avatarWidthRatio: innerHeight >= 680 ? 0.85 : (innerHeight >= 560 ? 0.75 : 0.60)
            readonly property real avatarSize: Math.min(root.centerWidth * avatarWidthRatio, innerHeight * avatarHeightRatio)
            readonly property real avatarMargin: innerHeight >= 680 ? Math.max(6, 8 * root.centerScale) : (innerHeight >= 560 ? 4 : 2)
            readonly property real centerItemMargin: innerHeight >= 680 ? Math.max(4, 6 * root.centerScale) : (innerHeight >= 560 ? 2 : 0)

            anchors.centerIn: parent
            width: root.lockLong
            height: root.lockShort
            visible: !root.isPortrait
            clip: true

            Item {
                anchors.fill: lockBg
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle { width: lockBg.width; height: lockBg.height; radius: lockBg.radius }
                }

                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: wallpaperBlur
                    sourceRect: Qt.rect(landscapeContent.x, landscapeContent.y, landscapeContent.width, landscapeContent.height)
                    live: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(root.clSurface.r, root.clSurface.g, root.clSurface.b, 0.50)
                }
            }

            Rectangle {
                id: lockBg
                anchors.fill: parent
                color: "transparent"
                border.color: Qt.rgba(root.clSurfaceVariantFg.r, root.clSurfaceVariantFg.g, root.clSurfaceVariantFg.b, 0.12)
                border.width: 1
                radius: root.bgRadius
            }

            RowLayout {
                id: landscapeLayout
                anchors.fill: parent
                anchors.margins: root.bgMargin
                spacing: 40 * (root.lockHeight / 1080)

                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: landscapeContent.colSpacing

                    WeatherCard {
                        id: weatherCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(landscapeContent.leftCardPool * 0.18)
                        implicitHeight: Layout.preferredHeight
                        cardRadius: root.cardRadius
                        centerScale: root.centerScale
                        clSurfaceContainer: root.clCardBg
                        clSurfaceFg: root.clSurfaceFg
                        clSurfaceVariantFg: root.clSurfaceVariantFg
                        clPrimary: root.clPrimary
                    }

                    CaelestiafetchCard {
                        id: fetchCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(landscapeContent.leftCardPool * 0.35)
                        implicitHeight: Layout.preferredHeight
                        cardRadius: root.cardRadius
                        centerScale: root.centerScale
                        fetchInfo: root.fetchInfo
                        clTerms: root.clTerms
                        recolourLogo: root.recolourLogo
                        clSurface: root.clSurface
                        clSurfaceContainer: root.clCardBg
                        clSurfaceContainerHigh: root.clCardBgHigh
                        clSurfaceContainerHighest: root.clSurfaceContainerHighest
                        clSurfaceFg: root.clSurfaceFg
                        clSurfaceVariantFg: root.clSurfaceVariantFg
                        clPrimary: root.clPrimary
                    }

                    MediaCard {
                        id: mediaCard
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: Math.max(0, landscapeContent.leftCardPool - weatherCard.Layout.preferredHeight - fetchCard.Layout.preferredHeight)
                        implicitHeight: Layout.preferredHeight
                        cardRadius: root.cardRadius
                        centerScale: root.centerScale
                        mediaInfo: ({})
                        clSurface: root.clSurface
                        clSurfaceContainer: root.clCardBg
                        clSurfaceFg: root.clSurfaceFg
                        clSurfaceVariantFg: root.clSurfaceVariantFg
                        clPrimary: root.clPrimary
                    }
                }

                Item {
                    id: centerColumnArea
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                    Layout.preferredWidth: root.centerWidth
                    Layout.fillWidth: false
                    Layout.fillHeight: true

                    ColumnLayout {
                        id: centerMainColumn
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: landscapeContent.centerSpacing

                        ClockWidget {
                            Layout.alignment: Qt.AlignHCenter
                            currentTime: root.currentTime
                            use12h: root.use12h
                            centerScale: root.centerScale
                            clPrimary: root.clPrimary
                            clSecondary: root.clSecondary
                            clSurfaceContainerHigh: root.clCardBgHigh
                            clSurfaceFg: root.clSurfaceFg
                            clSurfaceVariantFg: root.clSurfaceVariantFg
                        }

                        ProfileAvatar {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: landscapeContent.avatarMargin
                            Layout.bottomMargin: landscapeContent.avatarMargin
                            implicitWidth: landscapeContent.avatarSize
                            implicitHeight: landscapeContent.avatarSize
                            Layout.preferredWidth: implicitWidth
                            Layout.preferredHeight: implicitHeight
                            centerScale: root.centerScale
                            profileShape: root.profilePicShape
                            rotateShape: root.rotateProfilePic
                            userName: root.currentUserName
                            clSurfaceVariantFg: root.clSurfaceVariantFg
                            clSurfaceContainerHighest: root.clSurfaceContainerHighest

                            MouseArea {
                                anchors.fill: parent
                                enabled: userPicker.count > 1
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.cycleUser()
                            }
                        }

                        GreetingPill {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: landscapeContent.centerItemMargin
                            centerScale: root.centerScale
                            centerWidth: root.centerWidth
                            greetingInfo: root.greetingInfo
                            userName: root.currentUserName
                            clSurfaceVariantFg: root.clSurfaceVariantFg
                            clPrimary: root.clPrimary

                            MouseArea {
                                anchors.fill: parent
                                enabled: userPicker.count > 1
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.cycleUser()
                            }
                        }

                        PasswordPill {
                            id: passwordPill
                            Layout.alignment: Qt.AlignHCenter
                            centerScale: root.centerScale
                            centerWidth: root.centerWidth
                            pillWidth: root.passwordPillWidth
                            focus: !root.isPortrait
                            isAuthenticating: root.isAuthenticating
                            clError: root.clError
                            clSurfaceContainer: root.clCardBg
                            clSurfaceContainerHigh: root.clCardBgHigh
                            clSurfaceFg: root.clSurfaceFg
                            clSurfaceVariantFg: root.clSurfaceVariantFg
                            clPrimary: root.clPrimary
                            clPrimaryFg: root.clPrimaryFg
                            clSecondary: root.clSecondary
                            onLoginRequested: pass => root.startLogin(pass)
                        }

                        SessionBar {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: landscapeContent.centerItemMargin
                            centerScale: root.centerScale
                            isAuthenticating: root.isAuthenticating
                            clPrimary: root.clPrimary
                            clSurfaceVariantFg: root.clSurfaceVariantFg
                            currentSessionName: root.currentSessionName
                            hasMultipleSessions: sessionPicker.count > 1
                            onCycleSessionRequested: root.cycleSession()
                        }
                    }

                    Item {
                        id: landscapeStatusContainer
                        readonly property bool hasStatus: Boolean(root.authMessage)

                        anchors.top: centerMainColumn.bottom
                        anchors.topMargin: landscapeContent.innerHeight >= 680 ? 6 : 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: hasStatus ? Math.max(14, statusCol.implicitHeight) : 0
                        visible: hasStatus

                        Column {
                            id: statusCol
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            spacing: 4 * root.centerScale

                            Text {
                                id: errorText
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                visible: false
                                text: root.authMessage
                                font { pixelSize: LockScreenConfig.sizeSmall; family: LockScreenConfig.fontBody }
                                color: root.clError
                                wrapMode: Text.WordWrap
                                scale: 0.7
                                opacity: 0
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: landscapeContent.colSpacing

                    ResourcesCard {
                        id: resourcesCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(landscapeContent.rightCardPool * 0.23)
                        implicitHeight: Layout.preferredHeight
                        cardRadius: root.cardRadius
                        centerScale: root.centerScale
                        liveCpu: root.liveCpu
                        liveTemp: root.liveTemp
                        liveRam: root.liveRam
                        liveDisk: root.liveDisk
                        cpuPercentage: Cpu.percentage ?? 0
                        memoryPercentage: Memory.percentage ?? 0
                        storagePercentage: Storage.percentage ?? 0
                        clSurface: root.clSurface
                        clSurfaceContainer: root.clCardBg
                        clSurfaceContainerHigh: root.clCardBgHigh
                        clSurfaceContainerHighest: root.clSurfaceContainerHighest
                        clPrimaryContainer: root.clPrimaryContainer
                        clSecondaryContainer: root.clSecondaryContainer
                        clTertiary: root.clTertiary
                        clOnTertiary: root.clOnTertiary
                        clOutline: root.clOutline
                        clSurfaceFg: root.clSurfaceFg
                        clSurfaceVariantFg: root.clSurfaceVariantFg
                        clPrimary: root.clPrimary
                        clSecondary: root.clSecondary
                        clError: root.clError
                    }

                    NotifDock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: Math.max(0, landscapeContent.rightCardPool - resourcesCard.Layout.preferredHeight)
                        cardRadius: root.cardRadius
                        centerScale: root.centerScale
                        isCaelestiaMode: root.isCaelestiaMode
                        clSurfaceContainer: root.clCardBg
                        clSurfaceContainerHigh: root.clCardBgHigh
                        clSurfaceContainerHighest: root.clSurfaceContainerHighest
                        clSecondaryContainer: root.clSecondaryContainer
                        clSurfaceFg: root.clSurfaceFg
                        clSurfaceVariantFg: root.clSurfaceVariantFg
                        clOutline: root.clOutline
                    }
                }
            }
        }

        Item {
            id: portraitContent

            anchors.centerIn: parent
            width: Math.min(parent.width * 0.9, root.lockShort)
            height: portraitLayout.implicitHeight + 64 * root.centerScale
            visible: root.isPortrait
            clip: true

            Item {
                anchors.fill: portraitBg
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle { width: portraitBg.width; height: portraitBg.height; radius: root.bgRadius }
                }

                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: wallpaperBlur
                    sourceRect: Qt.rect(portraitContent.x, portraitContent.y, portraitContent.width, portraitContent.height)
                    live: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(root.clSurface.r, root.clSurface.g, root.clSurface.b, 0.50)
                }
            }

            Rectangle {
                id: portraitBg
                anchors.fill: parent
                color: "transparent"
                border.color: Qt.rgba(root.clSurfaceVariantFg.r, root.clSurfaceVariantFg.g, root.clSurfaceVariantFg.b, 0.12)
                border.width: 1
                radius: root.bgRadius
            }

            ColumnLayout {
                id: portraitLayout
                anchors.centerIn: parent
                width: parent.width - 48 * root.centerScale
                spacing: 20 * root.centerScale

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    spacing: 24 * root.centerScale

                    ProfileAvatar {
                        Layout.preferredWidth: root.centerWidth * 0.4
                        Layout.preferredHeight: Layout.preferredWidth
                        centerScale: root.centerScale
                        profileShape: root.profilePicShape
                        rotateShape: root.rotateProfilePic
                        userName: root.currentUserName
                        clSurfaceVariantFg: root.clSurfaceVariantFg
                        clSurfaceContainerHighest: root.clSurfaceContainerHighest
                    }

                    ClockWidget {
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                        currentTime: root.currentTime
                        use12h: root.use12h
                        centerScale: root.centerScale
                        clPrimary: root.clPrimary
                        clSecondary: root.clSecondary
                        clSurfaceContainerHigh: root.clCardBgHigh
                        clSurfaceFg: root.clSurfaceFg
                        clSurfaceVariantFg: root.clSurfaceVariantFg
                    }
                }

                GreetingPill {
                    Layout.alignment: Qt.AlignHCenter
                    centerScale: root.centerScale
                    centerWidth: root.centerWidth
                    greetingInfo: root.greetingInfo
                    userName: root.currentUserName
                    clSurfaceVariantFg: root.clSurfaceVariantFg
                    clPrimary: root.clPrimary
                }

                PasswordPill {
                    id: portraitPasswordPill
                    Layout.alignment: Qt.AlignHCenter
                    centerScale: root.centerScale
                    centerWidth: root.centerWidth
                    pillWidth: root.passwordPillWidth
                    focus: root.isPortrait
                    isAuthenticating: root.isAuthenticating
                    clError: root.clError
                    clSurfaceContainer: root.clCardBg
                    clSurfaceContainerHigh: root.clCardBgHigh
                    clSurfaceFg: root.clSurfaceFg
                    clSurfaceVariantFg: root.clSurfaceVariantFg
                    clPrimary: root.clPrimary
                    clPrimaryFg: root.clPrimaryFg
                    clSecondary: root.clSecondary
                    onLoginRequested: pass => root.startLogin(pass)
                }

                Text {
                    id: portraitErrorText
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: false
                    text: root.authMessage
                    font { pixelSize: LockScreenConfig.sizeSmall; family: LockScreenConfig.fontBody }
                    color: root.clError
                    wrapMode: Text.WordWrap
                    scale: 0.7
                    opacity: 0
                }

                SessionBar {
                    Layout.alignment: Qt.AlignHCenter
                    centerScale: root.centerScale
                    isAuthenticating: root.isAuthenticating
                    clPrimary: root.clPrimary
                    clSurfaceVariantFg: root.clSurfaceVariantFg
                    currentSessionName: root.currentSessionName
                    hasMultipleSessions: sessionPicker.count > 1
                    onCycleSessionRequested: root.cycleSession()
                }
            }
        }
    }
}
