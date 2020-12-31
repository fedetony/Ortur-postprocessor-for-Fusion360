/**
  Ortur Master 2 CAM post processor for Fusion360
  Compatible with Grbl 1.1+

  By F.Garcia
  https://github.com/fedetony/

  Adapted from Tech2C (HyperCube.cps) on https://www.thingiverse.com/thing:1752766
*/
description = "Ortur Laser for Fusion360";
vendor = "grbl";
vendorUrl = "https://github.com/gnea/grbl/wiki";
longDescription = "Generic milling post for Grbl. Use 'Split file' property to split files by tool for tool changes.";
vendorUrl = "Grbl";

extension = "gcode";
setCodePage("ascii");

capabilities = CAPABILITY_INTERMEDIATE;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

// user-defined properties
properties = {
  setPositionXY: true,  
  useMetricUnits: true,
  startHome: false,
  finishHome: false,
  finishPositionX: "",
  finishPositionY: "",
  //finishBeep: false,
  rapidTravelXY: 6000,
  laserEtch: "M3 S500",
  laserVaperize: "M3 S1000",
  laserThrough: "M3 S100",
  laserOFF: "M5 S0"
};

var xyzFormat = createFormat({decimals:3});
var feedFormat = createFormat({decimals:0});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var planeOutput = createVariable({prefix:"G"}, feedFormat);

// circular output
var	iOutput	= createReferenceVariable({prefix:"I"}, xyzFormat);
var	jOutput	= createReferenceVariable({prefix:"J"}, xyzFormat);
var	kOutput	= createReferenceVariable({prefix:"K"}, xyzFormat);

var cuttingMode;

function formatComment(text) {
  return String(text).replace(/[\(\)]/g, "");
}

function writeComment(text) {
  writeWords(formatComment(text));
}

function onOpen() {
  writeln(";***********************************************************************************");
  writeln(";Ortur CAM post processor for Fusion360: Version 1.0");
  writeln(";Compatible with 2 axes machines using Grbl 0.9 or 1.1");
  writeln(";By F.Garcia");
  writeln(";https://github.com/fedetony/");
  writeln(";***********************************************************************************");
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of X, Y, Z, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

function onSection() {
  if(isFirstSection()) {
    writeln("");
	writeWords("; Starting...");
	writeWords(properties.laserOFF, "         ;Laser/Fan OFF");
    if(properties.useMetricUnits) {writeWords("G21", "          ;Metric Values");}
    else {writeWords("G20", "          ;Non Metric Units");}
    //writeWords("G21", "          ;Metric Values");
	writeWords(planeOutput.format(17), "          ;Plane XY");
	writeWords("G90", "          ;Absolute Positioning");
	if(properties.setPositionXY) {writeWords("G92 X0 Y0 Z0", " ;Set XYZ Positions");}
	//writeWords("G0", feedOutput.format(properties.rapidTravelXY));
	if(properties.startHome) { writeWords("$H", "        ;Home"); }
	//if(properties.startPositionZ) { writeWords("G0 Z" + properties.startPositionZ, feedOutput.format(properties.rapidTravelZ), "   ;Position Z"); }
}
  
  if (currentSection.getType() == TYPE_JET) {
    if(currentSection.jetMode == 0) {cuttingMode = properties.laserThrough }
	else if(currentSection.jetMode == 1) {cuttingMode = properties.laserEtch }
	else if(currentSection.jetMode == 2) {cuttingMode = properties.laserVaperize }
	else {cuttingMode = (properties.laserOFF + "         ;Unknown Laser Cutting Mode") }
  }
  
  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
	  writeln("");
	  //writeWords("M400");
      writeComment("; " + comment);
    }
  }
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.001, seconds, 99999.999);
  writeWords("G4 S" + seconds, "        ;Dwell time");
}

function onPower(power) {
  if (power) { writeWords(cuttingMode) }
  else { writeWords(properties.laserOFF) }
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y) {
    writeWords("G0", x, y, feedOutput.format(properties.rapidTravelXY));
  }
  if (z) {
    writeWords("G0", z, feedOutput.format(properties.rapidTravelZ));
  }
}

function onLinear(_x, _y, _z, _feed) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(_feed);
  if(x || y || z) {
    writeWords("G1", x, y, z, f);
  }
  else if (f) {
    writeWords("G1", f);
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  // one of X/Y and I/J are required and likewise
  var start = getCurrentPosition();
  
  switch (getCircularPlane()) {
  case PLANE_XY:
    writeWords(planeOutput.format(17), (clockwise ? "G2":"G3"), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
    break;
  case PLANE_ZX:
    break;
    //writeWords(planeOutput.format(18), (clockwise ? "G2":"G3"), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
    //break;
  case PLANE_YZ:
    break;
    //writeWords(planeOutput.format(19), (clockwise ? "G2":"G3"), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
	//break;
  default:
    linearize(tolerance);
  }
}

function onSectionEnd() {
  writeWords(planeOutput.format(17));
  forceAny();
}

function onClose() {
  writeln("");
  //writeWords("M400");
  writeWords(properties.laserOFF, "         ;Laser/Fan OFF");
  //if(properties.finishPositionZ) { writeWords("G0 Z" + properties.finishPositionZ, feedOutput.format(properties.rapidTravelZ), "   ;Position Z"); }
  //writeWords("G0", feedOutput.format(properties.rapidTravelXY));
  if(properties.finishHome) { writeWords("$H", "        ;Home "); }
  if(properties.finishPositionX) { writeWords("G0 X" + properties.finishPositionX, "      ;End Position X"); }
  if(properties.finishPositionY) { writeWords("G0 Y" + properties.finishPositionY, "      ;End Position Y"); }
  //writeWords("M84", "          ;Motors OFF");
  //if(properties.finishBeep) { writeWords("M300 S800 P300"); }
  writeWords("; Finished :)");
}
