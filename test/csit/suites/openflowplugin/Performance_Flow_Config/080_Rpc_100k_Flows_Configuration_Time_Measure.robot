*** Settings ***
Documentation     Suite checks if StatMngr is able to collect flows correctly
Suite Setup       Create Http Session
Suite Teardown    Delete Http Session And Store Plot Data
Library           OperatingSystem
Library           Collections
Library           XML
Library           SSHLibrary
Variables         ../../../variables/Variables.py
Library           RequestsLibrary
Library           ../../../libraries/Common.py
Library           ../../../libraries/ScaleClient.py
Resource          ../../../libraries/WaitForFailure.robot

*** Variables ***
${swnr}           63
${flnr}           100000
${fpr}            25
${nrthreads}      5
${swspread}       linear
${tabspread}      first
@{cntls}          ${CONTROLLER}
${linux_prompt}    >
${start_cmd}      sudo mn --controller=remote,ip=${CONTROLLER} --topo linear,${swnr} --switch ovsk,protocols=OpenFlow13
${iperiod}        1s
${ichange}        60s
${outfile}        flows_setup_time.csv
${setuptime}      0

*** Test Cases ***
Connect Mininet
    Connect Switches

Configure Flows
    [Documentation]   Setup of ${flnr} flows using rpc calls
    [Teardown]         SaveSetupTime
    ${flows}    ${notes}=    Generate New Flow Details    flows=${flnr}    switches=${swnr}    swspread=${swspread}    tabspread=${tabspread}
    Log    ${notes}
    ${starttime}=    Get Time    epoch
    ${res}=    Operations Add Flows Rpc    flow_details=${flows}    controllers=@{cntls}    nrthreads=${nrthreads}    fpr=${fpr}
    Log    ${res}
    Set Suite Variable    ${flows}
    Log To Console    ${res}

Wait Stats Collected
    [Documentation]    Waits till ${flnr} flows are initially collected
    Inventory Change Reached    ${swnr}    ${flnr}

Deconfigure Flows
    [Documentation]    Flows deconfiguration
    ${res}=    Operations Remove Flows Rpc    flow_details=${flows}    controllers=@{cntls}    nrthreads=${nrthreads}    fpr=${fpr}
    Log    ${res}

Check No Flows In Operational After Remove
    [Documentation]    No flows should be found after their removeal
    Inventory Change Reached    ${swnr}    0

Stop Mininet End
    Stop Switches

*** Keywords ***
Connect Switches
    [Documentation]    Starts mininet with requested number of switches (${swnr})
    Log    Starting mininet with ${swnr} switches
    Open Connection    ${MININET}    prompt=${linux_prompt}    timeout=600
    Login With Public Key    ${MININET_USER}    ${USER_HOME}/.ssh/id_rsa    any
    Execute Command    sudo ovs-vsctl set-manager ptcp:6644
    Execute Command    sudo mn -c
    Write    ${start_cmd}
    Read Until    mininet>
    Wait Until Keyword Succeeds    10s    1s    Are Switches Connected Topo

Create Http Session
    Create Session    session    http://${CONTROLLER}:${RESTCONFPORT}    auth=${AUTH}    headers=${HEADERS_XML}

Stop Switches
    [Documentation]    Stops mininet
    Log    Stopping mininet
    Read
    Write    exit
    Read Until    ${linux_prompt}
    Close Connection

Delete Http Session And Store Plot Data
    Delete All Sessions
    Append To File    ${outfile}    FlowsSetupTime\n
    Append To File    ${outfile}    ${setuptime}\n

Are Switches Connected Topo
    [Documentation]    Checks wheather switches are connected to controller
    ${resp}=    Get    session    ${OPERATIONAL_TOPO_API}/topology/flow:1    headers=${ACCEPT_XML}
    Log    ${resp.content}
    ${count}=    Get Element Count    ${resp.content}    xpath=node
    Should Be Equal As Numbers    ${count}    ${swnr}

Check Flows Inventory
    [Arguments]    ${rswitches}    ${rflows}
    [Documentation]    Checks in inventory has required state
    ${sw}    ${repf}    ${foundf}=    Flow Stats Collected    controller=${CONTROLLER}
    Should Be Equal As Numbers    ${rswitches}    ${sw}
    Should Be Equal As Numbers    ${rflows}    ${foundf}

Save Setup Time
    [Documentation]    Count the difference and stores it
    ${endtime}=    Get Time    epoch
    Log    Stats collection finished at time ${endtime}
    ${setuptime}=    Evaluate    int(${endtime})-int(${starttime})
    Set Suite Variable    ${setuptime}

Inventory Change Reached
    [Arguments]    ${rswitches}    ${rflows}
    [Documentation]    This keywordwaits till inventory reaches required state
    Wait Until Keyword Succeeds    ${ichange}    ${iperiod}    Check Flows Inventory    ${rswitches}    ${rflows}
