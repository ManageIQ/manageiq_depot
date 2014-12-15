ManageIQ Community Depot
=========================

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



