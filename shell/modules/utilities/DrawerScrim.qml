pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

/// The dimmed backdrop a utilities-drawer modal sits on. Matches the exact
/// Utilities wrapper bounds (`Wrapper.qml`: `Tokens.padding.large` on all four
/// sides since v2.7.5) and `Surface.panelRounding` so the scrim never overflows
/// outside the drawer surface or its rounded corners.
Item {
    id: root

    required property matrix4x4 deformMatrix

    anchors.fill: parent
    anchors.margins: -Tokens.padding.large
    opacity: 0.5

    StyledRect {
        anchors.fill: parent
        radius: Surface.panelRounding
        color: Colours.palette.m3scrim
    }
}
