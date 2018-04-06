/* Copyright 2017 Esri
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */


import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import ArcGIS.AppFramework 1.0
import ArcGIS.AppFramework.Controls 1.0
import ArcGIS.AppFramework.Promises 1.0

App {
    id: app
    width: 800 * AppFramework.displayScaleFactor
    height: 600 * AppFramework.displayScaleFactor
    Material.theme: Material.Dark
        Material.accent: Material.Purple

    property var geoJson: null
    property string shapeFileName: "shapefile"
    property int ready: 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80 * AppFramework.displayScaleFactor
            color: "#8FA1C9"
            Text {

                anchors.fill: parent
                text: "Shapefile to GeoJSON [.shp --> .geojson]"
                font.pointSize: 12
                color: "white"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: dropArea.containsDrag ? "#D3B079" : "#485165"

                Text {
                    id: infoText
                    text: "Drag and drop .shp and associated .prj files here."
                    font {
                        family: Qt.application.font.family
                        pointSize: 10
                    }
                    color: "white"
                    wrapMode: Text.Wrap
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }


            DropArea {
                id: dropArea
                anchors.fill: parent
                onDropped: {

                    var projectionFilePath = "";
                    var coordinateSystem = "";
                    var shapeFilePath = "";

                    for (var x = 0; x < drop.urls.length; x++) {

                        var url = drop.urls[x].toString();

                        if (url.search(/.prj$/gi) > -1) {
                            projectionFilePath = url;
                        }
                        if (url.search(/.shp$/gi) > -1) {
                            shapeFilePath = url;
                        }
                    }

                    if (shapeFilePath === "" && projectionFilePath === "") {
                        infoText.text = qsTr("Suitable files: .json, .geojson OR .shp and .prj");
                        return;
                    }

                    if (projectionFilePath === "") {
                        // projection needed. ask user to verify the shape files coordinate system.
                        infoText.text = qsTr("No .prj (projection) file detected in dropped files. .prj file required.");
                        return;
                    }
                    else {
                        _file.path = AppFramework.urlInfo(projectionFilePath).localFile;
                        _file.open(File.OpenModeReadOnly);
                        if (_file.isReadable){
                            var projectionInformation = _file.readLine();
                            _file.close();
                            var latLon = "GCS_WGS_1984"
                            var webMerc = "WGS_1984_Web_Mercator_Auxiliary_Sphere"

                            if (projectionInformation.search(/GCS_WGS_1984/i) > -1){
                                coordinateSystem = "4326";
                            }
                            if (projectionInformation.search(/WGS_1984_Web_Mercator_Auxiliary_Sphere/i) > -1){
                                coordinateSystem = "3857";
                            }

                            if (coordinateSystem === ""){
                                // alert user that this isn't 4326 or 3587. They can proceed but may not be accurate
                                infoText.text = "Shapefile projection must be GCS_WGS_1984 (4326) or WGS_1984_Web_Mercator_Auxiliary_Sphere (3857)";
                                coordinateSystem = "";
                                return;
                            }
                        }
                    }

                    if (shapeFilePath !== "") {
                        shapeFileName = AppFramework.fileInfo(shapeFilePath).baseName;
                        busy.visible = true;
                        geoJson = null;
                        workerScript.sendMessage({"path": shapeFilePath, "coordinate_system": coordinateSystem});
                    }
                }
            }

            Rectangle {
                id: busy
                color: "#242832"
                anchors.fill: parent
                visible: false

                Button {
                    visible: completedInformation.visible
                    width: 50 * AppFramework.displayScaleFactor
                    height: 50 * AppFramework.displayScaleFactor
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 10
                    anchors.rightMargin: 10
                    z: 1000
                    text: "X"
                    font.pointSize: 20
                    onClicked: {
                        geoJson = null;
                        busy.visible = false;
                        completedInformation.visible = false;
                        saveGeoJsonButton.visible = true;

                        infoText.text = "Drag and drop .shp and associated .prj files here."
                    }
                }

                RowLayout {
                    visible: !completedInformation.visible
                    width: parent.width * .7
                    height: 200 * AppFramework.displayScaleFactor
                    anchors.centerIn: parent
                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: height
                        BusyIndicator {
                            id: busyIndicator
                            width: 100 * AppFramework.displayScaleFactor
                            height: width
                            anchors.centerIn: parent
                            running: true
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Text {
                            id: statusText
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: "white"
                            font.pointSize: 20
                        }
                    }
                }

                RowLayout {
                    id: completedInformation
                    width: parent.width * .7
                    height: 200 * AppFramework.displayScaleFactor
                    anchors.centerIn: parent
                    visible: false

                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Text {
                            id: completedText
                            anchors.fill: parent
                            textFormat: Text.RichText
                            color: "white"
                            font.pointSize: 20
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 200 * AppFramework.displayScaleFactor
                        Button {
                            id: saveGeoJsonButton
                            width: parent.width
                            height: 50 * AppFramework.displayScaleFactor
                            anchors.centerIn: parent
                            text: "Save .geojson"
                            font.pointSize: 15

                            onClicked: {
                                var fileName = "%1.geojson".arg(shapeFileName);//.arg(Date.now().toString());
                                geoJsonFileFolder.writeJsonFile(fileName, geoJson);
                                completedText.font.pointSize = 12;
                                completedText.text = "Saved to: %1/%2".arg(geoJsonFileFolder.path).arg(fileName);
                                visible = false;
                            }
                        }
                    }
                }
            }
        }
    }

    File {
        id: _file

        onErrorChanged: {
            console.log('-------------error:', _file.errorString)
        }
    }

    FileFolder {
        id: geoJsonFileFolder
        path: AppFramework.userHomePath
    }

    WorkerScript {
        id: workerScript
        source: "reader.js"

        onMessage: {
            if (messageObject.hasOwnProperty("geojson")){
                infoText.text = "all done"
                geoJson = messageObject.geojson;
                completedInformation.visible = true;
                completedText.text = "Number of Features: %1".arg(geoJson.features.length)
            }
            if (messageObject.hasOwnProperty("error")){
                infoText.text = messageObject.error.message;
                 busy.visible = false;
            }

            if (messageObject.hasOwnProperty("status")){
               statusText.text = messageObject.status;
            }
        }
    }

}

