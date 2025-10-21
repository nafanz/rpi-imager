/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../qmlcomponents"

import RpiImager

WizardStepBase {
    id: root
    
    required property ImageWriter imageWriter
    required property var wizardContainer
    
    title: qsTr("Select your storage device")
    showNextButton: true
    nextButtonEnabled: wizardContainer && wizardContainer.selectedStorageName && wizardContainer.selectedStorageName.length > 0  // Disabled until user selects a storage device
    
    // Forward the nextClicked signal as next() function
    // Only auto-advance if no system drive confirmation dialog is needed
    function next() {
        root.nextClicked()
    }
    
    // Conditional next function for keyboard auto-advance
    // Only auto-advance for non-system drives
    function conditionalNext() {
        // Check if current selection is a system drive
        if (dstlist.currentIndex >= 0) {
            var currentItem = dstlist.itemAtIndex(dstlist.currentIndex)
            if (currentItem && currentItem.isSystem) {
                // Don't auto-advance for system drives - let the confirmation dialog handle it
                return
            }
        }
        // Safe to auto-advance for non-system drives
        root.nextClicked()
    }
    
    property alias dstlist: dstlist
    property string selectedDeviceName: ""
    
    Component.onCompleted: {
        // Register the ListView for keyboard navigation
        root.registerFocusGroup("storage_list", function(){
            return [dstlist, filterSystemDrives]
        }, 0)
        
        // Set the initial focus item to the ListView
        root.initialFocusItem = dstlist
    }
    
    // Removed drive list polling calls; backend handles device updates
    
    // Content
    content: [
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Storage device list fills available space
        SelectionListView {
            id: dstlist
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.imageWriter.getDriveList()
            delegate: dstdelegate
            keyboardAutoAdvance: true
            nextFunction: root.conditionalNext
            accessibleName: qsTr("Storage device list. Select a storage device. Use arrow keys to navigate, Enter or Space to select")
            accessibleDescription: ""
            
            onItemSelected: function(index, item) {
                if (index >= 0 && index < count && item && typeof item.selectDrive === "function") {
                    item.selectDrive()
                }
            }

            // Auto-select a safe default when drives appear
            onCountChanged: {
                if (dstlist.count > 0 && dstlist.currentIndex === -1) {
                    selectDefaultDrive()
                }
            }
            
            // No storage devices message
            Label {
                anchors.fill: parent
                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter
                visible: parent.count == 0
                text: qsTr("No storage devices found")
                font.bold: true
                color: Style.formLabelColor
            }
        }
        
        // Filter controls
        RowLayout {
            Layout.fillWidth: true
            
            Item {
                Layout.fillWidth: true
            }
            
            ImCheckBox {
                id: filterSystemDrives
                checked: true
                text: qsTr("Exclude system drives")

                onToggled: {
                    if (!checked) {
                        // If warnings are disabled, bypass the confirmation dialog
                        if (root.wizardContainer && root.wizardContainer.disableWarnings) {
                            // Leave checkbox unchecked and continue showing system drives
                            dstlist.forceActiveFocus()
                        } else {
                            // Ask for stern confirmation before disabling filtering
                            confirmUnfilterPopup.open()
                        }
                    }
                }
            }
        }
        

    }
    ]
    
    // Storage delegate component
    Component {
        id: dstdelegate
        
        Item {
            id: dstitem
            
            required property int index
            required property string device
            required property string description
            required property string size
            required property bool isUsb
            required property bool isScsi
            required property bool isReadOnly
            required property bool isSystem
            required property var mountpoints
            required property QtObject modelData
            
            readonly property bool shouldHide: isSystem && filterSystemDrives.checked
            readonly property bool unselectable: isReadOnly
            
            // Accessibility properties
            Accessible.role: Accessible.ListItem
            Accessible.name: dstitem.description
            Accessible.description: imageWriter.formatSize(parseFloat(dstitem.size)) + (dstitem.unselectable ? " - " + qsTr("Read-only") : "")
            Accessible.focusable: true
            Accessible.ignored: false
            
            // Function called by keyboard selection
            function selectDrive() {
                if (!unselectable) {
                    root.selectDstItem(dstitem)
                }
            }
            
            width: dstlist.width
            height: shouldHide ? 0 : 80
            visible: !shouldHide
            
            Rectangle {
                id: dstbgrect
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: (dstlist.currentIndex === dstitem.index) ? Style.listViewHighlightColor :
                       (dstMouseArea.containsMouse ? Style.listViewHoverRowBackgroundColor : Style.listViewRowBackgroundColor)
                radius: 0
                opacity: dstitem.unselectable ? 0.5 : 1.0
                anchors.rightMargin: (dstlist.contentHeight > dstlist.height ? Style.scrollBarWidth : 0)
                Accessible.ignored: true
                
                MouseArea {
                    id: dstMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: dstitem.unselectable ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                    enabled: !dstitem.unselectable
                    
                    onClicked: {
                        if (!dstitem.unselectable) {
                            dstlist.currentIndex = dstitem.index
                            root.selectDstItem(dstitem)
                        }
                    }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Style.listItemPadding
                    spacing: Style.spacingMedium
                    
                    // Storage icon
                    Image {
                        id: storageIcon
                        source: dstitem.isUsb ? "../icons/ic_usb_40px.svg" :
                                dstitem.isScsi ? "../icons/ic_storage_40px.svg" :
                                "../icons/ic_sd_storage_40px.svg"
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        // Rasterize vector sources at device pixel ratio to avoid aliasing/blurriness on HiDPI
                        sourceSize: Qt.size(Math.round(40 * Screen.devicePixelRatio), Math.round(40 * Screen.devicePixelRatio))
                        visible: source.toString().length > 0

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: Style.titleSeparatorColor
                            border.width: 1
                            radius: 0
                            visible: parent.status === Image.Error
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.spacingXXSmall
                        
                        Text {
                            text: dstitem.description
                            font.pixelSize: Style.fontSizeFormLabel
                            font.family: Style.fontFamilyBold
                            font.bold: true
                            color: dstitem.unselectable ? Style.formLabelDisabledColor : Style.formLabelColor
                            Layout.fillWidth: true
                        }
                        
                        Text {
                            text: imageWriter.formatSize(parseFloat(dstitem.size))
                            font.pixelSize: Style.fontSizeDescription
                            font.family: Style.fontFamily
                            color: dstitem.unselectable ? Style.formLabelDisabledColor : Style.textDescriptionColor
                            Layout.fillWidth: true
                        }
                        
                        Text {
                            text: dstitem.mountpoints.length > 0 ? 
                                  qsTr("Mounted as %1").arg(dstitem.mountpoints.join(", ")) : ""
                            font.pixelSize: Style.fontSizeSmall
                            font.family: Style.fontFamily
                            color: dstitem.unselectable ? Style.formLabelDisabledColor : Style.textMetadataColor
                            Layout.fillWidth: true
                            visible: dstitem.mountpoints.length > 0
                        }
                    }
                    
                    // Read-only indicator
                    Text {
                        text: qsTr("Read-only")
                        font.pixelSize: Style.fontSizeDescription
                        font.family: Style.fontFamily
                        color: Style.formLabelErrorColor
                        visible: dstitem.unselectable
                    }
                }
            }
        }
    }
    
    // Storage selection function
    function selectDstItem(dstitem) {
        if (dstitem.unselectable) {
            return
        }

        if (dstitem.isSystem) {
            // Show stern confirmation dialog requiring typing the name
            systemDriveConfirm.driveName = dstitem.description
            systemDriveConfirm.device = dstitem.device
            systemDriveConfirm.sizeStr = imageWriter.formatSize(parseFloat(dstitem.size))
            systemDriveConfirm.mountpoints = dstitem.mountpoints
            systemDriveConfirm.open()
            return
        }

        imageWriter.setDst(dstitem.device)
        selectedDeviceName = dstitem.description
        root.wizardContainer.selectedStorageName = dstitem.description

        // Do not auto-advance; enable Next
        root.nextButtonEnabled = true
    }

    // Select default drive by priority (never system):
    // 1) SD cards (not USB and not SCSI)
    // 2) USB storage devices
    // 3) Other non-system, non-readonly devices
    function selectDefaultDrive() {
        var model = root.imageWriter.getDriveList()
        if (!model || model.rowCount() === 0) return

        var deviceRole = 0x101
        var descriptionRole = 0x102
        var sizeRole = 0x103
        var isUsbRole = 0x104
        var isScsiRole = 0x105
        var isReadOnlyRole = 0x106
        var isSystemRole = 0x107
        var mountpointsRole = 0x108

        var sdIdx = -1
        var usbIdx = -1
        var otherIdx = -1

        for (var i = 0; i < model.rowCount(); i++) {
            var idx = model.index(i, 0)
            var isSystem = model.data(idx, isSystemRole)
            if (isSystem) continue
            var isReadOnly = model.data(idx, isReadOnlyRole)
            if (isReadOnly) continue
            var isUsb = model.data(idx, isUsbRole)
            var isScsi = model.data(idx, isScsiRole)

            if (!isUsb && !isScsi && sdIdx === -1) {
                sdIdx = i
            } else if (isUsb && usbIdx === -1) {
                usbIdx = i
            } else if (otherIdx === -1) {
                otherIdx = i
            }
        }

        var chosen = sdIdx !== -1 ? sdIdx : (usbIdx !== -1 ? usbIdx : otherIdx)
        if (chosen === -1) return

        var cidx = model.index(chosen, 0)
        var device = model.data(cidx, deviceRole)
        var description = model.data(cidx, descriptionRole)
        var size = model.data(cidx, sizeRole)
        var mountpoints = model.data(cidx, mountpointsRole)

        dstlist.currentIndex = chosen
        root.imageWriter.setDst(device)
        root.selectedDeviceName = description
        root.wizardContainer.selectedStorageName = description
        root.nextButtonEnabled = true
    }
    // Stern confirmation when disabling system drive filtering
    ConfirmUnfilterDialog {
        id: confirmUnfilterPopup
        overlayParent: root.wizardContainer && root.wizardContainer.overlayRootRef ? root.wizardContainer.overlayRootRef : (root.Window.window ? root.Window.window.overlayRootItem : null)
        onConfirmed: {
            // user chose to disable filter; leave checkbox unchecked
        }
        onCancelled: {
            // Re-enable the filter checkbox and keep system drives hidden
            filterSystemDrives.checked = true
        }
        onClosed: {
            if (filterSystemDrives.checked === false) {
                dstlist.forceActiveFocus()
            } else {
                filterSystemDrives.forceActiveFocus()
            }
        }
    }

    // Confirmation when selecting a system drive: type the exact name
    ConfirmSystemDriveDialog {
        id: systemDriveConfirm
        overlayParent: root.wizardContainer && root.wizardContainer.overlayRootRef ? root.wizardContainer.overlayRootRef : (root.Window.window ? root.Window.window.overlayRootItem : null)
        onConfirmed: {
            root.imageWriter.setDst(systemDriveConfirm.device)
            root.selectedDeviceName = systemDriveConfirm.driveName
            root.wizardContainer.selectedStorageName = systemDriveConfirm.driveName
            // Re-enable filtering after selection via confirmation path
            filterSystemDrives.checked = true
            // Enable Next
            root.nextButtonEnabled = true
            // Auto-advance after explicit confirmation on a system drive
            root.next()
        }
        onCancelled: {
            // no-op
        }
    }
} 