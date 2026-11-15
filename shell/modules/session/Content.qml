pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

Column {
    id: root

    required property DrawerVisibilities visibilities

    function runCommand(command: list<string>): void {
        root.visibilities.session = false;
        if (!SessionManager.exec(command))
            Quickshell.execDetached(command);
    }

    function requestConfirmation(title: string, message: string, confirmText: string, destructive: bool, command: list<string>, sourceButton: Item): void {
        sessionConfirmPopup.confirmTitle = title;
        sessionConfirmPopup.confirmMessage = message;
        sessionConfirmPopup.confirmText = confirmText;
        sessionConfirmPopup.destructive = destructive;
        sessionConfirmPopup.pendingCommand = command;
        sessionConfirmPopup.returnFocusTarget = sourceButton;
        sessionConfirmPopup.open();
    }

    padding: Tokens.padding.large
    rightPadding: CUtils.clamp(padding - Config.border.thickness, 0, padding)
    spacing: Tokens.spacing.large

    Connections {
        function onSessionChanged(): void {
            if (!root.visibilities.session)
                sessionConfirmPopup.close();
        }

        target: root.visibilities
    }

    SessionButton {
        id: logout

        label: qsTr("Log out")
        icon: Config.session.icons.logout
        command: ["sh", "-c", "qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout 2>/dev/null"]
        confirm: true
        confirmTitle: qsTr("Log out?")
        confirmMessage: qsTr("Your current desktop session will end and unsaved work may be lost.")

        KeyNavigation.down: shutdown

        Component.onCompleted: forceActiveFocus()

        Connections {
            function onLauncherChanged(): void {
                if (!root.visibilities.launcher)
                    logout.forceActiveFocus();
            }

            target: root.visibilities
        }
    }

    SessionButton {
        id: shutdown

        label: qsTr("Shut down")
        icon: Config.session.icons.shutdown
        command: Config.session.commands.shutdown
        confirm: true
        destructive: true
        confirmTitle: qsTr("Shut down computer?")
        confirmMessage: qsTr("All open apps will close and the system will power off.")

        KeyNavigation.up: logout
        KeyNavigation.down: sleep
    }

    Item {
        readonly property string resolvedGif: Config.paths.sessionGif || "root:/assets/dino.gif"
        readonly property bool isMonoDino: resolvedGif.endsWith("/dino.gif")

        width: Tokens.sizes.session.button
        height: Tokens.sizes.session.button

        AnimatedImage {
            anchors.fill: parent
            sourceSize.width: width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)
            playing: visible
            asynchronous: true
            speed: Config.general.sessionGifSpeed
            source: Paths.absolutePath(parent.resolvedGif)
            fillMode: AnimatedImage.PreserveAspectFit

            layer.enabled: parent.isMonoDino
            layer.effect: Colouriser {
                colorizationColor: Colours.palette.m3onSurface
                sourceColor: "white"
            }
        }
    }

    SessionButton {
        id: sleep

        label: qsTr("Sleep")
        icon: "bedtime"
        command: ["suspend"]

        KeyNavigation.up: shutdown
        KeyNavigation.down: SessionOptions.showHibernate ? hibernate : reboot
    }

    SessionButton {
        id: hibernate

        visible: SessionOptions.showHibernate
        label: qsTr("Hibernate")
        icon: Config.session.icons.hibernate
        command: Config.session.commands.hibernate
        confirm: true
        confirmTitle: qsTr("Hibernate computer?")
        confirmMessage: qsTr("Your session will be saved to disk and the system will power off.")

        KeyNavigation.up: sleep
        KeyNavigation.down: reboot
        onVisibleChanged: {
            if (!visible && activeFocus)
                reboot.forceActiveFocus();
        }
    }

    SessionButton {
        id: reboot

        label: qsTr("Restart")
        icon: Config.session.icons.reboot
        command: Config.session.commands.reboot
        confirm: true
        confirmTitle: qsTr("Restart computer?")
        confirmMessage: qsTr("All open apps will close and the system will reboot.")

        KeyNavigation.up: SessionOptions.showHibernate ? hibernate : sleep
    }

    Popup {
        id: sessionConfirmPopup

        property string confirmTitle
        property string confirmMessage
        property string confirmText
        property bool destructive
        property list<string> pendingCommand: []
        property Item returnFocusTarget: null

        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        padding: root.Tokens.padding.large

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: root.Tokens.anim.durations.expressiveDefaultEffects
                easing: root.Tokens.anim.expressiveDefaultEffects
            }
            NumberAnimation {
                property: "scale"
                from: 0.88
                to: 1
                duration: root.Tokens.anim.durations.expressiveFastSpatial
                easing: root.Tokens.anim.expressiveFastSpatial
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: root.Tokens.anim.durations.expressiveFastEffects
                easing: root.Tokens.anim.expressiveFastEffects
            }
            NumberAnimation {
                property: "scale"
                from: 1
                to: 0.92
                duration: root.Tokens.anim.durations.expressiveFastEffects
                easing: root.Tokens.anim.expressiveFastEffects
            }
        }

        onClosed: {
            if (root.visibilities.session)
                (returnFocusTarget && returnFocusTarget.visible ? returnFocusTarget : logout).forceActiveFocus();
        }

        contentItem: ColumnLayout {
            spacing: root.Tokens.spacing.medium

            StyledText {
                Layout.fillWidth: true
                Layout.maximumWidth: 320
                text: sessionConfirmPopup.confirmTitle
                font: root.Tokens.font.body.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                Layout.fillWidth: true
                Layout.maximumWidth: 320
                text: sessionConfirmPopup.confirmMessage
                color: Colours.palette.m3onSurfaceVariant
                font: root.Tokens.font.body.small
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: root.Tokens.spacing.small

                TextButton {
                    text: qsTr("Cancel")
                    onClicked: sessionConfirmPopup.close()
                }

                TextButton {
                    text: sessionConfirmPopup.confirmText
                    type: TextButton.Filled
                    inactiveColour: sessionConfirmPopup.destructive ? Colours.palette.m3error : Colours.palette.m3primary
                    inactiveOnColour: sessionConfirmPopup.destructive ? Colours.palette.m3onError : Colours.palette.m3onPrimary
                    onClicked: {
                        const cmd = sessionConfirmPopup.pendingCommand;
                        sessionConfirmPopup.close();
                        root.runCommand(cmd);
                    }
                }
            }
        }

        background: Item {
            Elevation {
                anchors.fill: sessionBgRect
                level: 3
                radius: sessionBgRect.radius
            }

            StyledRect {
                id: sessionBgRect

                anchors.fill: parent
                radius: root.Tokens.rounding.large
                color: Colours.palette.m3surfaceContainerHigh
                border.width: 1
                border.color: Colours.palette.m3outlineVariant
            }
        }
    }

    component SessionButton: ButtonBase {
        id: button

        required property list<string> command
        required property string label
        property string icon
        property bool confirm: false
        property string confirmTitle: label
        property string confirmMessage
        property bool destructive: false

        function exec(): void {
            if (confirm)
                root.requestConfirmation(confirmTitle, confirmMessage, label, destructive, command, button);
            else
                root.runCommand(command);
        }

        implicitWidth: Tokens.sizes.session.button
        implicitHeight: content.implicitHeight + Tokens.padding.medium * 2

        inactiveColour: activeFocus ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        inactiveOnColour: activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        radius: pressed ? Tokens.rounding.medium : activeFocus ? Tokens.rounding.extraLarge : Tokens.rounding.largeIncreased
        onClicked: exec()

        Keys.onEnterPressed: exec()
        Keys.onReturnPressed: exec()
        Keys.onEscapePressed: root.visibilities.session = false
        Keys.onPressed: event => {
            if (!Config.session.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if ((event.key === Qt.Key_J || event.key === Qt.Key_N) && KeyNavigation.down) {
                    KeyNavigation.down.focus = true;
                    event.accepted = true;
                } else if ((event.key === Qt.Key_K || event.key === Qt.Key_P) && KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab && KeyNavigation.down) {
                KeyNavigation.down.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            }
        }

        Column {
            id: content

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.icon
                color: button.onColour
                fontStyle: Tokens.font.icon.builders.large.scale(1.3).build()
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.label
                color: button.onColour
                font: Tokens.font.label.small
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
