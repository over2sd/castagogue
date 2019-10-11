# castagogue
RSS generator for faith-based organizations with relatively stable event calendars.

# roadmap
1 - generate continuing feed from existing file

2 - upload rss file to given location and filename

3 - create new feed file from input parameters

4 - read %tokens% from daily.txt to allow randomized lists of media (Proverb of the Day, etc.)?

5 - upload attached media to file server

6 - pretty GUI to make editing day files easier

# config files
monday.txt, etc - every Monday

tuesday2.txt, etc - 2nd Tuesday of each month

wednesdayeven.txt, thursdayodd.txt - 2nd & 4th Wednesdays, Odd Thursdays (1st, 3rd, & 5th)

date15.txt - 15th of each month

daily.txt - every day (see roadmap 4)

# prerequisites
cpan:

install Config::IniFiles

install XML::LibXML::Reader

install XML::RSS

install DateTime

install DateTime::Format::Duration

install DateTime::Format::DateParse

install WWW::Mechanize

install Prima (only required for GUI program picked.pl)
