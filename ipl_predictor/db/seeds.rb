# IPL Teams with historical stats (2008-2024)
# wins/losses/titles are career totals used to seed win-rate calculations
teams_data = [
  { name: "Mumbai Indians",           short_name: "MI",   titles: 5, home_ground: "Wankhede Stadium" },
  { name: "Chennai Super Kings",      short_name: "CSK",  titles: 5, home_ground: "MA Chidambaram Stadium" },
  { name: "Kolkata Knight Riders",    short_name: "KKR",  titles: 3, home_ground: "Eden Gardens" },
  { name: "Royal Challengers Bengaluru", short_name: "RCB", titles: 1, home_ground: "M. Chinnaswamy Stadium" },
  { name: "Sunrisers Hyderabad",      short_name: "SRH",  titles: 1, home_ground: "Rajiv Gandhi International Stadium" },
  { name: "Rajasthan Royals",         short_name: "RR",   titles: 2, home_ground: "Sawai Mansingh Stadium" },
  { name: "Delhi Capitals",           short_name: "DC",   titles: 0, home_ground: "Arun Jaitley Stadium" },
  { name: "Punjab Kings",             short_name: "PBKS", titles: 0, home_ground: "Punjab Cricket Association Stadium" },
  { name: "Gujarat Titans",           short_name: "GT",   titles: 1, home_ground: "Narendra Modi Stadium" },
  { name: "Lucknow Super Giants",     short_name: "LSG",  titles: 0, home_ground: "BRSABV Ekana Cricket Stadium" },
]

teams_data.each do |attrs|
  Team.find_or_create_by!(short_name: attrs[:short_name]) do |t|
    t.name        = attrs[:name]
    t.titles      = attrs[:titles]
    t.home_ground = attrs[:home_ground]
  end
end

puts "Seeded #{Team.count} teams."

# Seed historical head-to-head match data (IPL 2008-2024, selected key matches)
# Format: [team1_short, team2_short, winner_short, season, venue, date]
historical_matches = [
  # 2008
  ["KKR", "RCB", "KKR",  2008, "Eden Gardens",               "2008-04-18"],
  ["CSK", "MI",  "CSK",  2008, "MA Chidambaram Stadium",      "2008-04-20"],
  ["RR",  "DC",  "RR",   2008, "Sawai Mansingh Stadium",      "2008-04-22"],
  ["MI",  "RCB", "MI",   2008, "Wankhede Stadium",            "2008-04-27"],
  ["CSK", "KKR", "CSK",  2008, "MA Chidambaram Stadium",      "2008-05-01"],
  # 2009
  ["MI",  "CSK", "MI",   2009, "Wankhede Stadium",            "2009-04-18"],
  ["RR",  "MI",  "RR",   2009, "Sawai Mansingh Stadium",      "2009-04-22"],
  ["DC",  "CSK", "CSK",  2009, "Arun Jaitley Stadium",        "2009-04-25"],
  ["KKR", "PBKS","KKR",  2009, "Eden Gardens",                "2009-05-02"],
  # 2010
  ["CSK", "MI",  "MI",   2010, "MA Chidambaram Stadium",      "2010-03-13"],
  ["KKR", "RCB", "RCB",  2010, "Eden Gardens",                "2010-03-16"],
  ["MI",  "RR",  "MI",   2010, "Wankhede Stadium",            "2010-03-20"],
  ["CSK", "DC",  "CSK",  2010, "MA Chidambaram Stadium",      "2010-03-24"],
  ["RCB", "PBKS","RCB",  2010, "M. Chinnaswamy Stadium",      "2010-03-28"],
  # 2011
  ["CSK", "MI",  "CSK",  2011, "MA Chidambaram Stadium",      "2011-04-08"],
  ["RCB", "KKR", "RCB",  2011, "M. Chinnaswamy Stadium",      "2011-04-11"],
  ["PBKS","RR",  "RR",   2011, "Punjab Cricket Association Stadium", "2011-04-14"],
  ["MI",  "DC",  "MI",   2011, "Wankhede Stadium",            "2011-04-18"],
  # 2012
  ["KKR", "CSK", "KKR",  2012, "Eden Gardens",                "2012-04-04"],
  ["MI",  "RCB", "MI",   2012, "Wankhede Stadium",            "2012-04-07"],
  ["DC",  "RR",  "DC",   2012, "Arun Jaitley Stadium",        "2012-04-10"],
  ["CSK", "SRH", "CSK",  2012, "MA Chidambaram Stadium",      "2012-04-14"],
  # 2013
  ["MI",  "CSK", "MI",   2013, "Wankhede Stadium",            "2013-04-06"],
  ["KKR", "MI",  "KKR",  2013, "Eden Gardens",                "2013-04-10"],
  ["SRH", "RCB", "SRH",  2013, "Rajiv Gandhi International Stadium", "2013-04-14"],
  ["RR",  "DC",  "RR",   2013, "Sawai Mansingh Stadium",      "2013-04-18"],
  ["CSK", "PBKS","CSK",  2013, "MA Chidambaram Stadium",      "2013-04-21"],
  # 2014
  ["CSK", "MI",  "CSK",  2014, "MA Chidambaram Stadium",      "2014-04-10"],
  ["SRH", "KKR", "KKR",  2014, "Rajiv Gandhi International Stadium", "2014-04-14"],
  ["RCB", "PBKS","RCB",  2014, "M. Chinnaswamy Stadium",      "2014-04-17"],
  ["MI",  "RR",  "MI",   2014, "Wankhede Stadium",            "2014-04-20"],
  # 2015
  ["MI",  "CSK", "MI",   2015, "Wankhede Stadium",            "2015-04-08"],
  ["RCB", "KKR", "KKR",  2015, "M. Chinnaswamy Stadium",      "2015-04-12"],
  ["SRH", "DC",  "SRH",  2015, "Rajiv Gandhi International Stadium", "2015-04-15"],
  ["RR",  "PBKS","RR",   2015, "Sawai Mansingh Stadium",      "2015-04-18"],
  ["CSK", "KKR", "KKR",  2015, "MA Chidambaram Stadium",      "2015-04-22"],
  # 2016
  ["RCB", "SRH", "SRH",  2016, "M. Chinnaswamy Stadium",      "2016-04-09"],
  ["MI",  "RR",  "MI",   2016, "Wankhede Stadium",            "2016-04-12"],
  ["KKR", "DC",  "KKR",  2016, "Eden Gardens",                "2016-04-15"],
  ["SRH", "MI",  "SRH",  2016, "Rajiv Gandhi International Stadium", "2016-04-19"],
  ["KKR", "RCB", "KKR",  2016, "Eden Gardens",                "2016-04-23"],
  # 2017
  ["SRH", "RCB", "SRH",  2017, "Rajiv Gandhi International Stadium", "2017-04-05"],
  ["MI",  "KKR", "MI",   2017, "Wankhede Stadium",            "2017-04-08"],
  ["RR",  "DC",  "DC",   2017, "Sawai Mansingh Stadium",      "2017-04-11"],
  ["SRH", "KKR", "SRH",  2017, "Rajiv Gandhi International Stadium", "2017-04-15"],
  ["MI",  "RCB", "MI",   2017, "Wankhede Stadium",            "2017-04-18"],
  # 2018
  ["CSK", "MI",  "CSK",  2018, "MA Chidambaram Stadium",      "2018-04-07"],
  ["RCB", "KKR", "RCB",  2018, "M. Chinnaswamy Stadium",      "2018-04-10"],
  ["SRH", "RR",  "SRH",  2018, "Rajiv Gandhi International Stadium", "2018-04-14"],
  ["DC",  "PBKS","PBKS", 2018, "Arun Jaitley Stadium",        "2018-04-17"],
  ["CSK", "SRH", "CSK",  2018, "MA Chidambaram Stadium",      "2018-04-21"],
  # 2019
  ["CSK", "RCB", "CSK",  2019, "MA Chidambaram Stadium",      "2019-03-23"],
  ["MI",  "DC",  "MI",   2019, "Wankhede Stadium",            "2019-03-27"],
  ["SRH", "KKR", "SRH",  2019, "Rajiv Gandhi International Stadium", "2019-03-30"],
  ["RR",  "PBKS","PBKS", 2019, "Sawai Mansingh Stadium",      "2019-04-03"],
  ["CSK", "KKR", "CSK",  2019, "MA Chidambaram Stadium",      "2019-04-07"],
  # 2020
  ["MI",  "CSK", "MI",   2020, "Dubai International Cricket Stadium", "2020-09-19"],
  ["DC",  "KKR", "DC",   2020, "Dubai International Cricket Stadium", "2020-09-26"],
  ["SRH", "RCB", "RCB",  2020, "Dubai International Cricket Stadium", "2020-09-21"],
  ["RR",  "CSK", "RR",   2020, "Sharjah Cricket Stadium",     "2020-09-22"],
  ["MI",  "KKR", "MI",   2020, "Abu Dhabi Cricket Stadium",   "2020-10-18"],
  ["DC",  "SRH", "DC",   2020, "Dubai International Cricket Stadium", "2020-10-17"],
  # 2021
  ["MI",  "RCB", "RCB",  2021, "MA Chidambaram Stadium",      "2021-04-09"],
  ["CSK", "DC",  "CSK",  2021, "Wankhede Stadium",            "2021-04-10"],
  ["SRH", "KKR", "KKR",  2021, "MA Chidambaram Stadium",      "2021-04-11"],
  ["RR",  "PBKS","RR",   2021, "Wankhede Stadium",            "2021-04-12"],
  ["CSK", "MI",  "CSK",  2021, "Dubai International Cricket Stadium", "2021-09-19"],
  ["KKR", "DC",  "DC",   2021, "Dubai International Cricket Stadium", "2021-10-03"],
  # 2022
  ["GT",  "LSG", "GT",   2022, "Brabourne Stadium",           "2022-04-17"],
  ["CSK", "MI",  "MI",   2022, "DY Patil Stadium",            "2022-04-21"],
  ["KKR", "RCB", "RCB",  2022, "DY Patil Stadium",            "2022-04-27"],
  ["SRH", "DC",  "DC",   2022, "Brabourne Stadium",           "2022-04-22"],
  ["GT",  "RR",  "GT",   2022, "Brabourne Stadium",           "2022-05-04"],
  ["LSG", "KKR", "LSG",  2022, "DY Patil Stadium",            "2022-05-18"],
  # 2023
  ["CSK", "GT",  "GT",   2023, "Narendra Modi Stadium",       "2023-04-03"],
  ["MI",  "RCB", "MI",   2023, "Wankhede Stadium",            "2023-04-08"],
  ["LSG", "DC",  "LSG",  2023, "BRSABV Ekana Cricket Stadium", "2023-04-10"],
  ["SRH", "RR",  "RR",   2023, "Rajiv Gandhi International Stadium", "2023-04-14"],
  ["GT",  "CSK", "CSK",  2023, "Narendra Modi Stadium",       "2023-04-28"],
  ["MI",  "KKR", "KKR",  2023, "Wankhede Stadium",            "2023-05-06"],
  ["CSK", "GT",  "CSK",  2023, "Narendra Modi Stadium",       "2023-05-28"],  # Final
  # 2024
  ["CSK", "RCB", "RCB",  2024, "MA Chidambaram Stadium",      "2024-03-22"],
  ["MI",  "GT",  "GT",   2024, "Narendra Modi Stadium",       "2024-03-24"],
  ["KKR", "SRH", "KKR",  2024, "Eden Gardens",                "2024-03-26"],
  ["DC",  "PBKS","DC",   2024, "Arun Jaitley Stadium",        "2024-03-28"],
  ["LSG", "RR",  "RR",   2024, "BRSABV Ekana Cricket Stadium", "2024-03-30"],
  ["SRH", "MI",  "SRH",  2024, "Rajiv Gandhi International Stadium", "2024-04-07"],
  ["RCB", "KKR", "KKR",  2024, "M. Chinnaswamy Stadium",      "2024-04-21"],
  ["GT",  "CSK", "GT",   2024, "Narendra Modi Stadium",       "2024-04-23"],
  ["KKR", "SRH", "KKR",  2024, "Eden Gardens",                "2024-05-26"],  # Final
]

team_lookup = Team.all.index_by(&:short_name)

historical_matches.each do |t1_short, t2_short, winner_short, season, venue, date|
  t1     = team_lookup[t1_short]
  t2     = team_lookup[t2_short]
  winner = team_lookup[winner_short]
  next unless t1 && t2 && winner

  Match.find_or_create_by!(
    team1: t1, team2: t2, season: season, match_date: Date.parse(date)
  ) do |m|
    m.venue  = venue
    m.winner = winner
  end
end

puts "Seeded #{Match.count} matches."
