var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var encode3bits = func(first, second, third) {
  var integer = first;
  integer = integer + 2 * second;
  integer = integer + 4 * third;
  return integer;
}
var versionString = getprop("sim/version/flightgear");
var version = split(".", versionString);
var major = num(version[0]);
var minor = num(version[1]);
var pica  = num(version[2]);
var pickingMethod = 0;
if ((major == 2017 and minor == 2 and pica >= 1) or (major == 2017 and minor > 2) or major > 2017) {
    pickingMethod = 1;
}

var FALSE = 0;
var TRUE  = 1;

var AIR = 0;
var MARINE = 1;
var SURFACE = 2;
var ORDNANCE = 3;

var Contact = {
    # For now only used in guided missiles, to make it compatible with Mirage 2000-5.
    new: func(c, class) {
        var obj             = { parents : [Contact]};
#debug.benchmark("radar process1", func {
        obj.rdrProp         = c.getNode("radar");
        obj.oriProp         = c.getNode("orientation");
        obj.velProp         = c.getNode("velocities");
        obj.posProp         = c.getNode("position");
        obj.heading         = obj.oriProp.getNode("true-heading-deg");
#});
#debug.benchmark("radar process2", func {
        obj.alt             = obj.posProp.getNode("altitude-ft");
        obj.lat             = obj.posProp.getNode("latitude-deg");
        obj.lon             = obj.posProp.getNode("longitude-deg");
#});
#debug.benchmark("radar process3", func {
        #As it is a geo.Coord object, we have to update lat/lon/alt ->and alt is in meters
        obj.coord = geo.Coord.new();
        obj.coord.set_latlon(obj.lat.getValue(), obj.lon.getValue(), obj.alt.getValue() * FT2M);
#});
#debug.benchmark("radar process4", func {
        obj.pitch           = obj.oriProp.getNode("pitch-deg");
        obj.roll            = obj.oriProp.getNode("roll-deg");
        obj.speed           = obj.velProp.getNode("true-airspeed-kt");
        obj.vSpeed          = obj.velProp.getNode("vertical-speed-fps");
        obj.callsign        = c.getNode("callsign", 1);
        obj.shorter         = c.getNode("model-shorter");
        obj.orig_callsign   = obj.callsign.getValue();
        obj.name            = c.getNode("name");
        obj.sign            = c.getNode("sign",1);
        obj.valid           = c.getNode("valid");
        obj.painted         = c.getNode("painted");
        obj.unique          = c.getNode("unique");
        obj.validTree       = 0;
#});
#debug.benchmark("radar process5", func {        
        #obj.transponderID   = c.getNode("instrumentation/transponder/transmitted-id");
#});
#debug.benchmark("radar process6", func {                
        obj.acType          = c.getNode("sim/model/ac-type");
        obj.type            = c.getName();
        obj.index           = c.getIndex();
        obj.string          = "ai/models/" ~ obj.type ~ "[" ~ obj.index ~ "]";
        obj.shortString     = obj.type ~ "[" ~ obj.index ~ "]";
#});
#debug.benchmark("radar process7", func {
        obj.range           = obj.rdrProp.getNode("range-nm");
        obj.bearing         = obj.rdrProp.getNode("bearing-deg");
        obj.elevation       = obj.rdrProp.getNode("elevation-deg");
#});        
        obj.deviation       = nil;

        obj.node            = c;
        obj.class           = class;

        obj.polar           = [0,0];
        obj.cartesian       = [0,0];
        
        return obj;
    },

    isValid: func () {
      var valid = me.valid.getValue();
      if (valid == nil) {
        valid = FALSE;
      }
      if (me.callsign.getValue() != me.orig_callsign) {
        valid = FALSE;
      }
      return valid;
    },

    isPainted: func () {
      if (me.painted == nil) {
        me.painted = me.node.getNode("painted");
      }
      if (me.painted == nil) {
        return nil;
      }
      var p = me.painted.getValue();
      return p;
    },

    getUnique: func () {
      if (me.unique == nil) {
        me.unique = me.node.getNode("unique");
      }
      if (me.unique == nil) {
        return nil;
      }
      var u = me.unique.getValue();
      return u;
    },

    getElevation: func() {
        var e = 0;
        e = me.elevation.getValue();
        if(e == nil or e == 0) {
            # AI/MP has no radar properties
            var self = geo.aircraft_position();
            me.get_Coord();
            var angleInv = clamp(self.distance_to(me.coord)/self.direct_distance_to(me.coord), -1, 1);
            e = (self.alt()>me.coord.alt()?-1:1)*math.acos(angleInv)*R2D;
        }
        return e;
    },

    getNode: func () {
      return me.node;
    },

    getFlareNode: func () {
      return me.node.getNode("rotors/main/blade[3]/flap-deg");
    },

    getChaffNode: func () {
      return me.node.getNode("rotors/main/blade[3]/position-deg");
    },

    setPolar: func(dist, angle) {
      me.polar = [dist,angle];
    },

    setCartesian: func(x, y) {
      me.cartesian = [x,y];
    },

    remove: func(){
        if(me.validTree != 0){
          me.validTree.setValue(0);
        }
    },

    get_Coord: func(){
        me.coord.set_latlon(me.lat.getValue(), me.lon.getValue(), me.alt.getValue() * FT2M);
        var TgTCoord  = geo.Coord.new(me.coord);
        return TgTCoord;
    },

    get_Callsign: func(){
        var n = me.callsign.getValue();
        if(n != "" and n != nil) {
            return n;
        }
        if (me.name == nil) {
          me.name = me.getNode().getNode("name");
        }
        if (me.name == nil) {
          n = "";
        } else {
          n = me.name.getValue();
        }
        if(n != "" and n != nil) {
            return n;
        }
        n = me.sign.getValue();
        if(n != "" and n != nil) {
            return n;
        }
        return "UFO";
    },

    get_model: func(){
        var n = "";
        if (me.shorter == nil) {
          me.shorter = me.node.getNode("model-shorter");
        }
        if (me.shorter != nil) {
          n = me.shorter.getValue();
        }
        if(n != "" and n != nil) {
            return n;
        }
        n = me.sign.getValue();
        if(n != "" and n != nil) {
            return n;
        }
        if (me.name == nil) {
          me.name = me.getNode().getNode("name");
        }
        if (me.name == nil) {
          n = "";
        } else {
          n = me.name.getValue();
        }
        if(n != "" and n != nil) {
            return n;
        }
        return me.get_Callsign();
    },

    get_Speed: func(){
        # return true airspeed
        var n = me.speed.getValue();
        return n;
    },

    get_Longitude: func(){
        var n = me.lon.getValue();
        return n;
    },

    get_Latitude: func(){
        var n = me.lat.getValue();
        return n;
    },

    get_Pitch: func(){
        var n = me.pitch.getValue();
        return n;
    },

    isVirtual: func(){
        return 0;
    },

    get_Roll: func(){
        var n = me.roll.getValue();
        return n;
    },

    get_heading : func(){
        var n = me.heading.getValue();
        if(n == nil)
        {
            n = 0;
        }
        return n;
    },

    get_bearing: func(){
        var n = 0;
        n = me.bearing.getValue();
        if(n == nil or n == 0) {
            # AI/MP has no radar properties
            n = me.get_bearing_from_Coord(geo.aircraft_position());
        }
        return n;
    },

    get_bearing_from_Coord: func(MyAircraftCoord){
        me.get_Coord();
        var myBearing = 0;
        if(me.coord.is_defined()) {
            myBearing = MyAircraftCoord.course_to(me.coord);
        }
        return myBearing;
    },

    get_reciprocal_bearing: func(){
        return geo.normdeg(me.get_bearing() + 180);
    },

    get_deviation: func(true_heading_ref, coord){
        me.deviation =  - deviation_normdeg(true_heading_ref, me.get_bearing_from_Coord(coord));
        return me.deviation;
    },

    get_altitude: func(){
        #Return Alt in feet
        return me.alt.getValue();
    },

    get_Elevation_from_Coord: func(MyAircraftCoord) {
        me.get_Coord();
        var value = (me.coord.alt() - MyAircraftCoord.alt()) / me.coord.direct_distance_to(MyAircraftCoord);
        if (math.abs(value) > 1) {
          # warning this else will fail if logged in as observer and see aircraft on other side of globe
          return 0;
        }
        var myPitch = math.asin(value) * R2D;
        return myPitch;
    },

    get_total_elevation_from_Coord: func(own_pitch, MyAircraftCoord){
        var myTotalElevation =  - deviation_normdeg(own_pitch, me.get_Elevation_from_Coord(MyAircraftCoord));
        return myTotalElevation;
    },
    
    get_total_elevation: func(own_pitch) {
        me.deviation =  - deviation_normdeg(own_pitch, me.getElevation());
        return me.deviation;
    },

    get_range: func() {
        var r = 0;
        if(me.range == nil or me.range.getValue() == nil or me.range.getValue() == 0) {
            # AI/MP has no radar properties
            me.get_Coord();
            r = me.coord.direct_distance_to(geo.aircraft_position()) * M2NM;
        } else {
          r = me.range.getValue();
        }
        return r;
    },

    get_range_from_Coord: func(MyAircraftCoord) {
        var myCoord = me.get_Coord();
        var myDistance = 0;
        if(myCoord.is_defined()) {
            myDistance = MyAircraftCoord.direct_distance_to(myCoord) * M2NM;
        }
        return myDistance;
    },

    get_type: func () {
      return me.class;
    },

    get_cartesian: func() {
      return me.cartesian;
    },

    get_polar: func() {
      return me.polar;
    },
};

var isNotBehindTerrain = func( mp ) {

###########
	var pos = mp.getNode("position");
	var alt = pos.getNode("altitude-ft").getValue();
	var lat = pos.getNode("latitude-deg").getValue();
	var lon = pos.getNode("longitude-deg").getValue();
	if(alt == nil or lat == nil or lon == nil) {
		return isVisible = 0;
	}
	var aircraftPos = geo.Coord.new().set_latlon(lat, lon, alt*0.3048);
#################
    if (pickingMethod == 1) {
      var myPos = geo.aircraft_position();
      myPos.set_latlon(myPos.lat(),myPos.lon(),myPos.alt()+50);
      var xyz = {"x":myPos.x(),                  "y":myPos.y(),                 "z":myPos.z()};
      var dir = {"x":aircraftPos.x()-myPos.x(),  "y":aircraftPos.y()-myPos.y(), "z":aircraftPos.z()-myPos.z()};

      # Check for terrain between own aircraft and other:
      v = get_cart_ground_intersection(xyz, dir);
      if (v == nil) {
        return 1;
        #printf("No terrain, planes has clear view of each other");
      } else {
          var terrain = geo.Coord.new();
          terrain.set_latlon(v.lat, v.lon, v.elevation);
          var maxDist = myPos.direct_distance_to(aircraftPos);
          var terrainDist = myPos.direct_distance_to(terrain);
          if (terrainDist < maxDist) {
            #printf("terrain found between SAM and aircraft %.1f meter away.", terrainDist);
            return 0;
          } else {
              #print("The planes has clear view of each other");
              return 1;
          }
      }
    } else {
        var isVisible = 0;
        var MyCoord = geo.aircraft_position();
        
        # Because there is no terrain on earth that can be between these 2
        if(MyCoord.alt() < 8900 and aircraftPos.alt() < 8900)
        {
            # Temporary variable
            # A (our plane) coord in meters
            var a = MyCoord.x();
            var b = MyCoord.y();
            var c = MyCoord.z();
            # B (target) coord in meters
            var d = aircraftPos.x();
            var e = aircraftPos.y();
            var f = aircraftPos.z();
            var difa = d - a;
            var difb = e - b;
            var difc = f - c;
            # direct Distance in meters
            var myDistance = math.sqrt( math.pow((d-a),2) + math.pow((e-b),2) + math.pow((f-c),2)); #calculating distance ourselves to avoid another call to geo.nas (read: speed, probably).
            var Aprime = geo.Coord.new();
            
            # Here is to limit FPS drop on very long distance
            var L = 500;
            if(myDistance > 50000)
            {
                L = myDistance / 15;
            }
            var step = L;
            var maxLoops = int(myDistance / L);
            
            isVisible = 1;
            # This loop will make travel a point between us and the target and check if there is terrain
            for(var i = 1 ; i <= maxLoops ; i += 1)
            {
              #calculate intermediate step
              #basically dividing the line into maxLoops number of steps, and checking at each step
              #to ascii-art explain it:
              #  |us|----------|step 1|-----------|step 2|--------|step 3|----------|them|
              #there will be as many steps as there is i
              #every step will be equidistant

              #also, if i == 0 then the first step will be our plane

              var x = ((difa/(maxLoops+1))*i)+a;
              var y = ((difb/(maxLoops+1))*i)+b;
              var z = ((difc/(maxLoops+1))*i)+c;
              #print("i:" ~ i ~ "|x,y,z | " ~ x ~ "," ~ y ~ "," ~ z);
              Aprime.set_xyz(x,y,z);
              var AprimeTerrainAlt = geo.elevation(Aprime.lat(), Aprime.lon());
              if(AprimeTerrainAlt == nil)
              {
                AprimeTerrainAlt = 0;
              }

              if(AprimeTerrainAlt > Aprime.alt())
              {
                #print("behind terrain");
                return 0;
              }
            }
        }
        else
        {
            isVisible = 1;
        }
        return isVisible;
    }
}