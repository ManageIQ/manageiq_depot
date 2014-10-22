Service Item Selection (Updated) {.entry-title}
================================

Posted on [October 11,
2014](http://cloudformsnow.com/2014/10/11/service-item-selection/ "00:23")
by
[johnhardy36](http://cloudformsnow.com/author/johnhardy36/ "View all posts by johnhardy36")

Here is something I get a lot,

“How can I make a service with multiple service items, but then
conditional drop some during the deployment?”

Eg. You have a Service Dialog like this one here;

[Download Sample Dialog](scripts/Sample_Dialog.yaml)

[![Screen Shot 2014-10-10 at
14.11.00](images/screen-shot-2014-10-10-at-14-11-00.png)]

Giving the user the option to select QA, Test or Production.

The decision would evaluate to one of 3 backing Service Items. Shown
here in this diagram;

[![Slide1](images/slide1.png?w=600&h=450)]

Each service item here maybe RHEV, OpenStack or VMware. They might be
all AWS/EC2 but different AMI’s etc!

So back to the use case,

How do I remove the service items I do not want to use from the service
bundle (Nobody mention ZSTOP!)

Lets go through the solution;

- You need to have a state machine for EACH service item. It can be the same state machine, but either way you need to specify one.

So, when you create each service item, and I am not concerned with the
contents here (EC2, RHOS, RHEV, VMware etc..) You need to specify an
entry point to a state machine that you have edit rights to as show
here;

[![Screen Shot 2014-10-10 at
14.10.36](images/screen-shot-2014-10-10-at-14-10-36.png?w=600&h=364)]

[![Screen Shot 2014-10-10 at 14.10.49](images/screen-shot-2014-10-10-at-14-10-49.png?w=600&h=386)]

[![Screen Shot 2014-10-10 at 14.10.43](images/screen-shot-2014-10-10-at-14-10-43.png?w=600&h=390)]

The bundle that has these three service items can be whatever you like,
here is mine, its just using its own state machine as you should do, but
nothing special happening here.

[![Screen Shot 2014-10-10 at 14.10.24](images/screen-shot-2014-10-10-at-14-10-24.png?w=600&h=416)]

So looking at the Automate browser what do these state machines look
like in file view?

[![Screen Shot 2014-10-10 at 20.13.35](images/screen-shot-2014-10-10-at-20-13-35.png?w=348&h=300)]

- The state machine has many steps, Pre1, Pre2, Pre3, Provisioin, Post
Provision etc.. We want to edit Pre1 and put something for the state
machine to process. We are going to call out to a method that decides to
either keep this service item or to dump it out. So exactly like a
conditional processor but done using some simple ruby code rather than
the nice GUI’s we see in Control, Reporting and Filtering (That may come
later in ManageIQ hopefully)

The code simply takes the value from the Dialog for an attribute. In my
case it is “Dialog\_Environment”, the possible outcomes for this
attribute are “Test, QA or Production”

The next thing we do is take the value of the state machine we are
running, so I have added to the state machine schema an Attribute field
called “State\_Environment”. Now I know what the user selected and what
the current service I am running is.

So you should edit the schema of the
\<YourDOMAIN\>/Service/Provisioning/StateMachines/ServiceProvision\_Template
class to include this new attribute called “State\_Environment” here is
a picture to show you the finished edit;

[![Screen Shot 2014-10-10 at 20.20.31](images/screen-shot-2014-10-10-at-20-20-31.png?w=600&h=90)]

If the value of Dialog\_Environment is NOT same as State\_Environment
then we want to dump this Service Item.

Here is the method; Its called Stopper, its a state on each of the
Service Item State Machines, I shall show you this next;

  ------------------------------------ ------------------------------------
  1                                    `def`{.ruby .keyword}
  2                                    `mark_task_invalid(task)`{.ruby
  3                                    .plain}
  4                                    ` `{.ruby
  5                                    .spaces}`task.finished(`{.ruby
  6                                    .plain}`"Invalid"`{.ruby
  7                                    .string}`)`{.ruby .plain}
  8                                    ` `{.ruby
  9                                    .spaces}`task.miq_request_tasks.`{.r
  10                                   uby
  11                                   .plain}`each`{.ruby .keyword}
  12                                   `do`{.ruby .keyword} `|t|`{.ruby
  13                                   .plain}
  14                                   ` `{.ruby .spaces}`2`{.ruby
  15                                   .constants}`.times { `{.ruby
  16                                   .plain}`$evm`{.ruby .variable
  17                                   .bold}`.log(`{.ruby
  18                                   .plain}`"info"`{.ruby
  19                                   .string}`, `{.ruby
  20                                   .plain}`"***************************
  21                                   *****DUMPING TASK #{t}**************
  22                                   ***********************"`{.ruby
  23                                   .string}`) }`{.ruby .plain}
  24                                   ` `{.ruby
  25                                   .spaces}`mark_task_invalid(t)`{.ruby
  26                                   .plain}
  27                                   ` `{.ruby .spaces}`end`{.ruby
  28                                   .keyword}
                                       `end`{.ruby .keyword}
                                        
                                        
                                       `10`{.ruby
                                       .constants}`.times { `{.ruby
                                       .plain}`$evm`{.ruby .variable
                                       .bold}`.log(`{.ruby
                                       .plain}`"info"`{.ruby
                                       .string}`, `{.ruby
                                       .plain}`"***************************
                                       ************************************
                                       ******"`{.ruby
                                       .string}`) }`{.ruby .plain}
                                        
                                       `stp_task = `{.ruby
                                       .plain}`$evm`{.ruby .variable
                                       .bold}`.root[`{.ruby
                                       .plain}`"service_template_provision_
                                       task"`{.ruby
                                       .string}`]`{.ruby .plain}
                                       `miq_request_id = `{.ruby
                                       .plain}`$evm`{.ruby .variable
                                       .bold}`.vmdb(`{.ruby
                                       .plain}`'miq_request_task'`{.ruby
                                       .string}`, stp_task.get_option(`{.ru
                                       by
                                       .plain}`:parent_task_id`{.ruby
                                       .color2}`))`{.ruby .plain}
                                       `dialogOptions = miq_request_id.get_
                                       option(`{.ruby
                                       .plain}`:dialog`{.ruby
                                       .color2}`)`{.ruby .plain}
                                        
                                       `$evm`{.ruby .variable
                                       .bold}`.log(`{.ruby
                                       .plain}`"info"`{.ruby
                                       .string}`, `{.ruby
                                       .plain}`"Dialog_Environment #{dialog
                                       Options['dialog_environment'].downca
                                       se}"`{.ruby
                                       .string}`)`{.ruby .plain}
                                       `$evm`{.ruby .variable
                                       .bold}`.log(`{.ruby
                                       .plain}`"info"`{.ruby
                                       .string}`, `{.ruby
                                       .plain}`"State_Environment #{$evm.ro
                                       ot['State_Environment'].downcase}"`{
                                       .ruby
                                       .string}`)`{.ruby .plain}
                                        
                                       `if`{.ruby .keyword}
                                       `dialogOptions[`{.ruby
                                       .plain}`'dialog_environment'`{.ruby
                                       .string}`].downcase != `{.ruby
                                       .plain}`$evm`{.ruby .variable
                                       .bold}`.root[`{.ruby
                                       .plain}`'State_Environment'`{.ruby
                                       .string}`].downcase`{.ruby .plain}
                                       ` `{.ruby .spaces}`$evm`{.ruby
                                       .variable .bold}`.log(`{.ruby
                                       .plain}`"info"`{.ruby
                                       .string}`, `{.ruby
                                       .plain}`"NO MATCH - DUMPING Service 
                                       from resolution"`{.ruby
                                       .string}`)`{.ruby .plain}
                                       ` `{.ruby .spaces}`task = `{.ruby
                                       .plain}`$evm`{.ruby .variable
                                       .bold}`.root[`{.ruby
                                       .plain}`"service_template_provision_
                                       task"`{.ruby
                                       .string}`]`{.ruby .plain}
                                       ` `{.ruby
                                       .spaces}`mark_task_invalid(task)`{.r
                                       uby
                                       .plain}
                                       ` `{.ruby .spaces}`exit `{.ruby
                                       .plain}`MIQ_STOP`{.ruby .constants}
                                       `end`{.ruby .keyword}
                                        
                                       `$evm`{.ruby .variable
                                       .bold}`.log(`{.ruby
                                       .plain}`"info"`{.ruby
                                       .string}`, `{.ruby
                                       .plain}`"MATCH FOUND - Processing Se
                                       rvice Normally"`{.ruby
                                       .string}`)`{.ruby .plain}
                                        
                                       `10`{.ruby
                                       .constants}`.times { `{.ruby
                                       .plain}`$evm`{.ruby .variable
                                       .bold}`.log(`{.ruby
                                       .plain}`"info"`{.ruby
                                       .string}`, `{.ruby
                                       .plain}`"***************************
                                       ************************************
                                       ******"`{.ruby
                                       .string}`) }`{.ruby .plain}
  ------------------------------------ ------------------------------------

Download the [Stopper method here](scripts/Stopper.rb)

So, the Stopper method needs to be placed somewhere, I instructed you do
this on the Pre1 of EACH service item state machine. Here is an example
of the QA state machine, this is the entry point for the service item
QA. I have used the ON\_ENTRY state, but you must leave the other states
intact, you will see why in point number 3 coming next.

[![Screen Shot 2014-10-10 at 20.16.30](images/screen-shot-2014-10-10-at-20-16-30.png?w=600&h=348)]

- Now we do have a small issue to deal with, notice in the previous
step the code exit is MIQ\_STOP. This is great on one hand because it
stops this state machine processing any further, but breaks in another
as the ae\_result is populated with “error” and when the bundle starts
to look at its children for status it sees “error” and barfs out the
entire Service Bundle, not good. So we have to fake the ae\_result back
to OK once we know that the reason for being “Error” is because we want
it to be and not because its a genuine error. Make sense?

So we have an OOTB method called “update\_serviceprovision\_status”, its
the job of this method to watch the service deployments and bump the
return status around depending on its value. In here we simply do a
check to say;

Is the item we are looking at for status, have a status value of
“Invalid”, because this is unique and not a Cloudforms status, its been
set specially by us for this use case. If it is “Invalid” then we know
that this service needs its “ae\_result” forced to be “ok” and to exit
MIQ\_OK. Making everyone happy, the service bundle thinks its
provisioned the service when it actually did not, moving onto the next
service item in the bundle.

Here is the NEW check\_provision method that you need to create in your
domain, I would simply copy the one from;

/ManageIQ/Service/Provisioning/StateMachines/ServiceProvision\_Template/update\_serviceprovision\_status

And either copy this code in, just place it near the top, before the
processing of the objects;

  ------------------------------------ ------------------------------------
  1                                    `# Bypass errors for Invalid instanc
  2                                    es`{.ruby
  3                                    .comments}
  4                                    `if`{.ruby .keyword}
  5                                    `prov.message == `{.ruby
  6                                    .plain}`'Invalid'`{.ruby .string}
  7                                    `  `{.ruby .spaces}`$evm`{.ruby
  8                                    .variable .bold}`.log(`{.ruby
                                       .plain}`"info"`{.ruby
                                       .string}`,`{.ruby
                                       .plain}`"Skipping Invalid Services"`
                                       {.ruby
                                       .string}`)`{.ruby .plain}
                                       `  `{.ruby .spaces}`$evm`{.ruby
                                       .variable .bold}`.root[`{.ruby
                                       .plain}`'ae_result'`{.ruby
                                       .string}`] = `{.ruby
                                       .plain}`'ok'`{.ruby .string}
                                       `  `{.ruby
                                       .spaces}`message = `{.ruby
                                       .plain}`'Service Provisioned Success
                                       fully'`{.ruby
                                       .string}
                                       `  `{.ruby
                                       .spaces}`prov.finished(prov.message)
                                       `{.ruby
                                       .plain}
                                       `  `{.ruby .spaces}`exit `{.ruby
                                       .plain}`MIQ_OK`{.ruby .constants}
                                       `end`{.ruby .keyword}
  ------------------------------------ ------------------------------------

or [download this new one from here](scripts/update_serviceprovision_status.rb)

I hope this all works for you, its a great use case and one we
talk about all the time.

Obviously there are more than one way to do this, but most other routes
either fail the bundle (bad) or require generic service items and loads
more code. This is re-usable, could be prodctised and easily repeatable
without a lot of effort. With the new domains in 3.1 you can have this
in your tool box.

I will raise a discussion on talk.manageiq.org to share this, and get
input on having the GUI conditional processor available in the Service
Item designer phase.

