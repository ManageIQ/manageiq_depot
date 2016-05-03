ManageIQ Community Depot
=========================

**Note that this version of the ManageIQ Depot is being deprecated. Please browse and upload extensions with the new ManageIQ Depot at [https://depot.manageiq.org/](https://depot.manageiq.org/)**

---

Let's get ready for the ManageIQ Community Depot. Got a policy you want to share? State machine? A script that utilizes the REST API and object model? Put it in the community depot! The community depot (or just "the depot") is where the ManageIQ community shares and collaborates on ManageIQ software projects and extensions. 

This is the format of individual extensions in the repo:

- /images directory - where you place screenshots
- /scripts directory - where you place, you guessed it, code
- content.md - descriptive text and instructions for whoever will want to use it
- metadata.yaml - this contains the following definitions:
    - author: username
    - collaborator: comma,delimited,text
    - date: yyyy-mm-dd
    - name: free text
    - slug: text_no_spaces (same as the folder name for your extension)
    - tags: comma,delimited,text
    - description:
      this is free form text that features paragraphs and whatever else is necessary to give a brief description that will be displayed on the main index page
    - miq_ver: manageiq_release (right now this is 'anand')
    - dependencies: comma,delimited,list
    - src_url: http://github.com/or/whatever/git/interface/you/use
    - license: any OSI-approved license (see opensource.org/licenses)


How to Add Your Extension
=========================

- fork "manageiq_depot"
- add your extension to your local fork, following format guidance above
- make pull request
- we will evaluate the pull request and either accept or request more information
- you are responsible for issuing pull requests for future changes and versions


## Export Notice

By downloading ManageIQ software, you acknowledge that you understand all of the
following: ManageIQ software and technical information may be subject to the
U.S. Export Administration Regulations (the "EAR") and other U.S. and foreign
laws and may not be exported, re-exported or transferred (a) to any country
listed in Country Group E:1 in Supplement No. 1 to part 740 of the EAR
(currently, Cuba, Iran, North Korea, Sudan & Syria); (b) to any prohibited
destination or to any end user who has been prohibited from participating in
U.S. export transactions by any federal agency of the U.S. government; or (c)
for use in connection with the design, development or production of nuclear,
chemical or biological weapons, or rocket systems, space launch vehicles, or
sounding rockets, or unmanned air vehicle systems. You may not download ManageIQ
software or technical information if you are located in one of these countries
or otherwise subject to these restrictions. You may not provide ManageIQ
software or technical information to individuals or entities located in one of
these countries or otherwise subject to these restrictions. You are also
responsible for compliance with foreign law requirements applicable to the
import, export and use of ManageIQ software and technical information.

