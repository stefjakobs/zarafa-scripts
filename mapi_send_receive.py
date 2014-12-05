#!/usr/bin/python

import random
import time
import sys

from python_nagios import NagiosArgumentParser
from python_nagios import nagios_exit
from python_nagios import STATE_OK, STATE_CRITICAL, STATE_UNKNOWN, STATE_WARNING

# the unversioned zarafa package
try:
    import zarafa
except ImportError:
    print "CRITICAL ERROR: could not import zarafa"
    nagios_exit(STATE_CRITICAL)
except:
    print "CRITICAL ERROR: something unexcepted happend during the import of the zarafa package and its _NOT_ an ImportError: ", sys.exc_info()[0]
    nagios_exit(STATE_CRITICAL)

try:
    import MAPI
    from MAPI.Util import *
    from MAPI.Tags import *
except ImportError:
    print "CRITICAL ERROR: could not import mapi package. In theory this should never happen, as the zarafa module itself needs the MAPI package... "
    nagios_exit(STATE_CRITICAL)


############Verbosity Levels##################
# no verbose flag -> Parameter errors; end status
# -v -> Useing default parameters if optional parameters are given; testmail subject + mailreceiver address; when sending mail;  when waiting; when opening second session; when deleting found mail; 
# -vv -> all parsed arguments; subject of each mail read, while searching for the testmail (should maybe be vvv); 
# -vvv -> unused
##############################################


def main(argv = None):

    parser = NagiosArgumentParser("Sending and Receiving Mail via MAPI Test")
    parser.add_argument("-s", dest="server", help="the zarafa server", metavar="server")
    parser.add_argument("-u", dest="username", help="testmailaccount username", metavar="username")
    parser.add_argument("-p", dest="password", help="password for the testmailaccount", metavar="password")
    parser.add_argument("-H", dest="hostname", help="hostname for the testmailaccount", metavar="hostname")
    parser.add_timeout()
    args = parser.parse_args()

    if  args.username is None:
        print "You need the parameter -u for the username"
        nagios_exit(STATE_UNKNOWN)

    if args.server is None:
        print "You need the parameter -s for the zarafa server"
        nagios_exit(STATE_UNKNOWN)

    if args.hostname is None:
        print "You need the parameter -H for the hostname of the mail receivers address"
        nagios_exit(STATE_UNKNOWN)

    if args.password is None:
        # We just use an empty password and inform the user if verbose output is set
        if args.verbose_1:
            print "No password given, using empty password instead"
        args.password = ""

    if args.timeout is None:
        # No timeout given, use default (20)
        if args.verbose_1:
            print "No timeout given, using default (20 seconds)"
        args.timeout = 20.0

    # f*ck you zarafapackage, you won't get my script arguments.. these are MINE...
    # sane comment: the zarafa package always trys to use the args and stops with an error if there are unrecognized or 'wrong' parameters
    while len(sys.argv) > 1:
        sys.argv.remove(sys.argv[1])

    if args.verbose_2:
        print "Parameters:"
        print "Timeout: ", args.timeout
        print "Username: ", args.username
        print "Password: ", args.password
        print "Server: ", args.server
        print "host: ", args.hostname


    testmail_subject = 'Einladung zum Superschurkengeheimversteck #' + str(random.random());

    #################################################################################################################
    # Part 1: Sending a test mail											#
    #################################################################################################################

    receiver_address = args.username + '@' + args.hostname
    if args.verbose_1:
        print "Test mail subject: ", testmail_subject
        print "Mail receiver address: ", receiver_address
    try:
        zarafa_server = zarafa.Server(server_socket=args.server, auth_user=args.username, auth_pass=args.password)
        user_outbox = zarafa_server.user(args.username).store.outbox
        if args.verbose_1:
            print "Sending the testmail"
        user_outbox.create_item(subject=testmail_subject, to=receiver_address, body='This is an official MAPI-Testmail, do not read any further ... I said do NOT read ... whatever').send()
    except zarafa.ZarafaException as e:
        print "CRITICAL ERROR: ZarafaException: ", e
        nagios_exit(STATE_CRITICAL)
    # theres no function for closing the session, so it should get closed when the object is deleted after the last reference was used.. which should be somewhere here or later

    if args.verbose_1:
        print "Waiting ", args.timeout, " seconds now"
    time.sleep(args.timeout)

    #################################################################################################################
    # Part 2: Check for the sended mail										#
    #################################################################################################################

    if args.verbose_1:
        print "Starting session for user ", args.username, " now"
    try:
        user_store = zarafa.Server(server_socket=args.server, auth_user=args.username, auth_pass=args.password).user(args.username).store
        user_inbox = user_store.inbox
        user_sentmail = user_store.sentmail
        inbox_mails = user_inbox.items()
        sent_mails = user_sentmail.items()

    except MAPIError, err:
        if err.hr == MAPI_E_LOGIN_FAILED:
            print "CRITICAL ERROR: Login failed. Check credentials"
            nagios_exit(STATE_CRITICAL)
        elif err.hr == MAPI_E_NETWORK_ERROR:
            print "CRITICAL ERROR: Connection failed"
            nagios_exit(STATE_CRITICAL)
    except:
        print "CRITICAL ERROR:", sys.exc_info()[0]
        nagios_exit(STATE_CRITICAL)

    # search the testmail in the inbox and delete if found
    mail_found = 0
    for mail in inbox_mails:
        if args.verbose_2:
            print mail.subject
        if mail.subject == testmail_subject:
            mail_found = 1
            if args.verbose_1:
                print "Previous sended mail was found"
            try:
                user_inbox.delete(mail)
            except:
                print "CRITICAL ERROR:", sys.exc_info()[0]
                nagios_exit(STATUS_CRITICAL)
            break

    # delete mail from sended mails folder
    if args.verbose_1:
        print "Deleting mail from sended mails"

    for mail in sent_mails:
        if mail.subject == testmail_subject:
            try:
                user_sentmail.delete(mail)
            except:
                print "CRITICAL ERROR:", sys.exc_info()[0]
                nagios_exit(STATE_CRITICAL)
            break

    # check if mail was found and exit with final status
    if mail_found == 1:
        print "MAPI OK: Sended mail was found"
        nagios_exit(STATE_OK)
    print "MAPI CRITICAL: Sended mail not found"
    nagios_exit(STATE_CRITICAL)


if __name__ == '__main__':
    #locale.setlocale(locale.LC_ALL, '')
    sys.exit(main())

