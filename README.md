mtgo-cards
==========

Magic the Gathering Online cards reports

Takes as input an inventory dump from MtGO's collection view. The filters must be set to show cards you have zero of so that all existing cards will be included.

Parses this data and generates two XML files. One is essentially a database of all existing cards. The other contains your inventory. Other tools are used to analyze your inventory and produce reports such as the cards for which you don't have playsets or what cards for which you have extra.
