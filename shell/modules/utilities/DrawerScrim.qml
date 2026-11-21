pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

/// The dimmed backdrop a utilities-drawer modal sits on. Matches the exact
/// Utilities wrapper bounds (`Wrapper.qml`: `Tokens.padding.large` on top/left,
/// clamped `padding - border.thickness` on right/bottom) and `Surface.panelRounding`
/// so the scrim never overflows outside the drawer surface or its rounded corners.
Item {
    id: root

    required property matrix4x4 deformMatrix

    readonly property real tailPadding: CUtils.clamp(Tokens.padding.large - Config.border.thickness, 0, Tokens.padding.large)

    anchors.fill: parent
    anchors.leftMargin: -Tokens.padding.large
    anchors.topMargin: -Tokens.padding.large
    anchors.rightMargin: -tailPadding
    anchors.bottomMargin: -tailPadding
    opacity: 0.5

    StyledRect {
        anchors.fill: parent
        radius: Surface.panelRounding
        color: Colours.palette.m3scrim
    }
}
