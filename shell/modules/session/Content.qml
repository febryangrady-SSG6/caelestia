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

    SessionConfirmPopup {
        id: sessionConfirmPopup

        property Item returnFocusTarget: null

        tokens: root.Tokens
        parent: Overlay.overlay
        onConfirmed: command => root.runCommand(command)
        onClosed: {
            if (root.visibilities.session)
                (returnFocusTarget && returnFocusTarget.visible ? returnFocusTarget : logout).forceActiveFocus();
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
