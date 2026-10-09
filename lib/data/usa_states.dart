/// USA states dataset for automated trip planning.
/// Each state: capital, nickname, top 3 attractions, best months to visit.
class UsaStates {
  static const List<Map<String, dynamic>> all = [
    {'state': 'Alabama', 'capital': 'Montgomery', 'tag': 'Southern charm & civil rights history', 'attractions': ['Gulf Shores beaches', 'U.S. Space & Rocket Center', 'Montgomery civil rights trail'], 'best': 'Mar-May, Oct-Nov'},
    {'state': 'Alaska', 'capital': 'Juneau', 'tag': 'Glaciers, wildlife & northern lights', 'attractions': ['Denali National Park', 'Glacier cruises', 'Northern lights viewing'], 'best': 'Jun-Aug (summer), Dec-Mar (aurora)'},
    {'state': 'Arizona', 'capital': 'Phoenix', 'tag': 'Deserts, canyons & red rocks', 'attractions': ['Grand Canyon', 'Sedona red rocks', 'Antelope Canyon'], 'best': 'Mar-May, Oct-Nov'},
    {'state': 'Arkansas', 'capital': 'Little Rock', 'tag': 'Hot springs & Ozark mountains', 'attractions': ['Hot Springs National Park', 'Ozark trails', 'Crystal Bridges Museum'], 'best': 'Apr-Jun, Sep-Nov'},
    {'state': 'California', 'capital': 'Sacramento', 'tag': 'Beaches, Hollywood & tech', 'attractions': ['Golden Gate Bridge', 'Disneyland', 'Yosemite National Park'], 'best': 'Year-round (Sep-Nov best)'},
    {'state': 'Colorado', 'capital': 'Denver', 'tag': 'Rockies, skiing & craft beer', 'attractions': ['Rocky Mountain NP', 'Aspen skiing', 'Red Rocks Amphitheatre'], 'best': 'Dec-Mar (ski), Jun-Sep (hike)'},
    {'state': 'Connecticut', 'capital': 'Hartford', 'tag': 'Coastal towns & fall foliage', 'attractions': ['Mystic Seaport', 'Yale University', 'Fall foliage drives'], 'best': 'Sep-Oct, May-Jun'},
    {'state': 'Delaware', 'capital': 'Dover', 'tag': 'Tax-free shopping & beaches', 'attractions': ['Rehoboth Beach', 'Winterthur Gardens', 'Historic New Castle'], 'best': 'May-Sep'},
    {'state': 'Florida', 'capital': 'Tallahassee', 'tag': 'Theme parks & tropical beaches', 'attractions': ['Walt Disney World', 'Miami Beach', 'Everglades'], 'best': 'Dec-Apr'},
    {'state': 'Georgia', 'capital': 'Atlanta', 'tag': 'Peaches, history & hospitality', 'attractions': ['Savannah historic district', 'Atlanta Aquarium', 'Blue Ridge Mountains'], 'best': 'Mar-May, Sep-Nov'},
    {'state': 'Hawaii', 'capital': 'Honolulu', 'tag': 'Volcanoes, surf & aloha spirit', 'attractions': ['Waikiki Beach', 'Hawaii Volcanoes NP', 'Pearl Harbor'], 'best': 'Year-round (Apr-Jun, Sep-Nov best)'},
    {'state': 'Idaho', 'capital': 'Boise', 'tag': 'Potatoes, rivers & wilderness', 'attractions': ['Shoshone Falls', 'Sawtooth Mountains', 'Craters of the Moon'], 'best': 'Jun-Sep'},
    {'state': 'Illinois', 'capital': 'Springfield', 'tag': 'Chicago skyline & deep-dish pizza', 'attractions': ['Millennium Park', 'Navy Pier', 'Route 66 start'], 'best': 'May-Sep'},
    {'state': 'Indiana', 'capital': 'Indianapolis', 'tag': 'Racing & heartland farms', 'attractions': ['Indianapolis 500', 'Children\'s Museum', 'Indiana Dunes'], 'best': 'May-Sep'},
    {'state': 'Iowa', 'capital': 'Des Moines', 'tag': 'Cornfields & covered bridges', 'attractions': ['Bridges of Madison County', 'Field of Dreams', 'Maquoketa Caves'], 'best': 'May-Sep'},
    {'state': 'Kansas', 'capital': 'Topeka', 'tag': 'Prairies & Wizard of Oz', 'attractions': ['Tallgrass Prairie', 'Oz Museum', 'Stratica salt mine'], 'best': 'Apr-Jun, Sep-Oct'},
    {'state': 'Kentucky', 'capital': 'Frankfort', 'tag': 'Bourbon, bluegrass & horses', 'attractions': ['Mammoth Cave NP', 'Kentucky Derby', 'Bourbon Trail'], 'best': 'Apr-Jun, Sep-Oct'},
    {'state': 'Louisiana', 'capital': 'Baton Rouge', 'tag': 'Jazz, Creole & Mardi Gras', 'attractions': ['French Quarter', 'Mardi Gras', 'Bayou tours'], 'best': 'Feb-May, Oct-Dec'},
    {'state': 'Maine', 'capital': 'Augusta', 'tag': 'Lighthouses & lobster rolls', 'attractions': ['Acadia National Park', 'Portland Head Light', 'Bar Harbor'], 'best': 'Jun-Oct'},
    {'state': 'Maryland', 'capital': 'Annapolis', 'tag': 'Chesapeake Bay & blue crabs', 'attractions': ['Inner Harbor', 'Annapolis naval academy', 'Assateague Island'], 'best': 'Apr-Jun, Sep-Oct'},
    {'state': 'Massachusetts', 'capital': 'Boston', 'tag': 'History, Ivy League & cod', 'attractions': ['Freedom Trail', 'Cape Cod', 'Harvard Square'], 'best': 'May-Oct'},
    {'state': 'Michigan', 'capital': 'Lansing', 'tag': 'Great Lakes & Motown', 'attractions': ['Mackinac Island', 'Sleeping Bear Dunes', 'Henry Ford Museum'], 'best': 'Jun-Sep'},
    {'state': 'Minnesota', 'capital': 'St. Paul', 'tag': '10,000 lakes & Mall of America', 'attractions': ['Boundary Waters', 'Mall of America', 'North Shore'], 'best': 'Jun-Sep'},
    {'state': 'Mississippi', 'capital': 'Jackson', 'tag': 'Blues, riverboats & magnolias', 'attractions': ['Blues Trail', 'Natchez Trace', 'Gulf Coast'], 'best': 'Mar-May, Oct-Nov'},
    {'state': 'Missouri', 'capital': 'Jefferson City', 'tag': 'Gateway Arch & BBQ', 'attractions': ['Gateway Arch', 'Branson shows', 'Ozark caves'], 'best': 'Apr-Jun, Sep-Oct'},
    {'state': 'Montana', 'capital': 'Helena', 'tag': 'Big sky & Yellowstone gateway', 'attractions': ['Glacier National Park', 'Yellowstone (north)', 'Beartooth Highway'], 'best': 'Jun-Sep'},
    {'state': 'Nebraska', 'capital': 'Lincoln', 'tag': 'Sandhills & pioneer trails', 'attractions': ['Chimney Rock', 'Omaha Zoo', 'Sandhill crane migration'], 'best': 'May-Sep'},
    {'state': 'Nevada', 'capital': 'Carson City', 'tag': 'Vegas lights & desert art', 'attractions': ['Las Vegas Strip', 'Hoover Dam', 'Burning Man (Aug-Sep)'], 'best': 'Mar-May, Oct-Nov'},
    {'state': 'New Hampshire', 'capital': 'Concord', 'tag': 'White Mountains & fall colors', 'attractions': ['White Mountain NF', 'Lake Winnipesaukee', 'Kancamagus Highway'], 'best': 'Sep-Oct, Jun-Aug'},
    {'state': 'New Jersey', 'capital': 'Trenton', 'tag': 'Shore towns & diners', 'attractions': ['Jersey Shore', 'Atlantic City', 'Princeton'], 'best': 'May-Sep'},
    {'state': 'New Mexico', 'capital': 'Santa Fe', 'tag': 'Desert art & alien lore', 'attractions': ['Carlsbad Caverns', 'White Sands NP', 'Roswell'], 'best': 'Mar-May, Sep-Nov'},
    {'state': 'New York', 'capital': 'Albany', 'tag': 'The Big Apple & Niagara Falls', 'attractions': ['Times Square', 'Niagara Falls', 'Adirondacks'], 'best': 'Apr-Jun, Sep-Nov'},
    {'state': 'North Carolina', 'capital': 'Raleigh', 'tag': 'Blue Ridge & Outer Banks', 'attractions': ['Blue Ridge Parkway', 'Outer Banks', 'Biltmore Estate'], 'best': 'Apr-Jun, Sep-Nov'},
    {'state': 'North Dakota', 'capital': 'Bismarck', 'tag': 'Badlands & Theodore Roosevelt NP', 'attractions': ['Theodore Roosevelt NP', 'Maah Daah Hey Trail', 'Scandinavian heritage'], 'best': 'Jun-Sep'},
    {'state': 'Ohio', 'capital': 'Columbus', 'tag': 'Rock & Roll Hall of Fame', 'attractions': ['Cedar Point', 'Rock Hall Cleveland', 'Hocking Hills'], 'best': 'May-Sep'},
    {'state': 'Oklahoma', 'capital': 'Oklahoma City', 'tag': 'Route 66 & cowboy culture', 'attractions': ['National Cowboy Museum', 'Route 66', 'Wichita Mountains'], 'best': 'Apr-Jun, Sep-Oct'},
    {'state': 'Oregon', 'capital': 'Salem', 'tag': 'Waterfalls, coast & coffee', 'attractions': ['Multnomah Falls', 'Crater Lake NP', 'Oregon Coast'], 'best': 'Jun-Sep'},
    {'state': 'Pennsylvania', 'capital': 'Harrisburg', 'tag': 'Liberty Bell & Amish country', 'attractions': ['Independence Hall', 'Gettysburg', 'Lancaster Amish'], 'best': 'Apr-Jun, Sep-Oct'},
    {'state': 'Rhode Island', 'capital': 'Providence', 'tag': 'Tiny state, grand mansions', 'attractions': ['Newport Mansions', 'Cliff Walk', 'Block Island'], 'best': 'May-Oct'},
    {'state': 'South Carolina', 'capital': 'Columbia', 'tag': 'Charleston charm & palmettos', 'attractions': ['Charleston historic', 'Myrtle Beach', 'Congaree NP'], 'best': 'Mar-May, Sep-Nov'},
    {'state': 'South Dakota', 'capital': 'Pierre', 'tag': 'Mount Rushmore & Badlands', 'attractions': ['Mount Rushmore', 'Badlands NP', 'Custer State Park'], 'best': 'Jun-Sep'},
    {'state': 'Tennessee', 'capital': 'Nashville', 'tag': 'Music City & Smoky Mountains', 'attractions': ['Great Smoky Mountains NP', 'Graceland', 'Nashville honky-tonks'], 'best': 'Apr-Jun, Sep-Oct'},
    {'state': 'Texas', 'capital': 'Austin', 'tag': 'Everything\'s bigger', 'attractions': ['The Alamo', 'Big Bend NP', 'Austin live music'], 'best': 'Mar-May, Oct-Nov'},
    {'state': 'Utah', 'capital': 'Salt Lake City', 'tag': 'Mighty 5 national parks', 'attractions': ['Zion NP', 'Arches NP', 'Bryce Canyon'], 'best': 'Apr-Jun, Sep-Oct'},
    {'state': 'Vermont', 'capital': 'Montpelier', 'tag': 'Maple syrup & green mountains', 'attractions': ['Stowe skiing', 'Ben & Jerry\'s factory', 'Fall foliage'], 'best': 'Sep-Oct (foliage), Dec-Mar (ski)'},
    {'state': 'Virginia', 'capital': 'Richmond', 'tag': 'Historic triangle & Shenandoah', 'attractions': ['Colonial Williamsburg', 'Shenandoah NP', 'Arlington'], 'best': 'Apr-Jun, Sep-Oct'},
    {'state': 'Washington', 'capital': 'Olympia', 'tag': 'Evergreens & Space Needle', 'attractions': ['Space Needle', 'Olympic NP', 'Pike Place Market'], 'best': 'Jun-Sep'},
    {'state': 'West Virginia', 'capital': 'Charleston', 'tag': 'Wild & wonderful mountains', 'attractions': ['New River Gorge NP', 'Seneca Rocks', 'Whitewater rafting'], 'best': 'May-Oct'},
    {'state': 'Wisconsin', 'capital': 'Madison', 'tag': 'Cheese, lakes & the Dells', 'attractions': ['Wisconsin Dells', 'Door County', 'Lambeau Field'], 'best': 'Jun-Sep'},
    {'state': 'Wyoming', 'capital': 'Cheyenne', 'tag': 'Yellowstone & Grand Teton', 'attractions': ['Yellowstone NP', 'Grand Teton NP', 'Devils Tower'], 'best': 'Jun-Sep'},
  ];

  /// Search states by name.
  static List<Map<String, dynamic>> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((s) =>
            (s['state'] as String).toLowerCase().contains(q) ||
            (s['capital'] as String).toLowerCase().contains(q))
        .toList();
  }
}
