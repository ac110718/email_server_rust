## Rust Zero To Production 
<br>"Safe code allows you to take better risks"
<br>Cloud native applications strive to (1) achieve high-availability while running in fault-prone environments, (2) continuously release new versions with zero downtime, (3) handle dynamic workloads (ie volumes)
<br>Running a replicated application influences our approach to data persistence.
<br> leverage the type system to make undesirable states difficult or impossible to represent.

## Chapter 3 : Set Up

<br>HttpServer handles all transport level concerns. Socket, how many concurrent connections, TLS enable? What about afterwards?
<br> App handles all application logic: routing, request handlers. Job is to take an incoming request and spit out a response
<br> Use builder pattern. new() gives clean spate. Add new behavior chaining method calls one after the other.
<br>`web::get()` shortcut for request passing to handler if and only if its HTTP method is GET. App will iterate over all registered endpoints until path template + guard (method request) parameters are matched. Then it passed over the requestor object to the handler (greet function)
<br> `#[tokio::main]` is needed to make main function asynchronous (because HttpServer itself is async). Need to handle Futures, polling, etc. Under the hood, it just takes the body we've written and placed it under a parent (macro generated) block_on function
<br> Tests should be highly decoupled from the technology underpinning API implementation. What if you have refactoring. Should have framework agnostic testing. Embedded test modules have privileged access to code living next to it.. unit tests improves confidence in machinery.. but integration test (testing your code by calling it in same way a user would) calls for external tests and same level of external access.
<br> Tests should be (1) Arrange - Set up server, client, (2) Act - pass the action, (3) Assert vs. desired response
<br> Dev dependencies exclusively used when running tests or examples.
<br> HTML form data has special encoding with key=value pairs separated by '&' example: `name=le%20guin&email=ursula_le_guin%40gmail.com`

**THREADS ARE FOR WORKING IN PARALLEL, ASYNC IS FOR WAITING IN PARALLEL**

`set -x` enables a mode of the shell where all executed commands are printed to the terminal. `set -eo pipefail` e is immediate exit if any command fails. `o pipefail` prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline. By default, the pipeline's return code is that of the last command even if it succeeds.

`docker run -e` to set up environment variables.

Make things executable `chmod +x scripts/init_db.sh`

Database migration: changing schema in a database.

Application state: other pieces of data that are not related to the lifecycle of a single incoming request

HttpServer takes in a CLOSURE that returns an App, so there can be many instances (but anything passed into it must implement clone())

Route struct takes in both a handler, and guards. Guards specify conditions that must be "matched" before calling the handler, like must match the PATH + METHOD specified before calling the handler. web::get() is shortcut for Route::new().guard(guard::Get()) (new guard that identifies GET requests)

Async not natively built into rust. Rather you import a dependenciy so you can implement your own runtime that is optimized for your specific use case.

Backwards compatible changes (adding new features / endpoints) vs. breaking changes (removing or dropping fields) which will break existing code.

Tests that call handler functions internally will miss major parts of user journey like invoking GET requests, or invoking along specified HTTP path. Embedded tests are good for unit tests for private sub-components (but ultimately they have priveleged access that the end user may or may not have). Integration test = same way user would interact

Splitting between library and binary allows logic code to be imported into tests. main.rs is meant to be executable binary, not for "sharing"

Be careful at which level you run await, or run programs. For example, if you return an already "awaited" server, you'll be waiting on a specific instance of the server.. which is behavior you don't want because that instance will never end (it's live, running code that you don't want to import into test). Rather, what you specifically want is simply the FUTURE that you can pass into your own function and control / spawn in your own environment. Catch the server variable itself to ruwn on your own spawn thread.. rather than catching an instance of ALREADY spawned server 

When randomizing port for testing and you need to extract for both the server and client.. use indirection by creating instance of TcpListener that will independently produce a connection (with its own port number). Extract the port number to feed into both the server and client. If you directly bind the URL to the server.. there's no way to re-extract the port that was randomized by the OS

parameterised test. Give an array of invalid error.. each of which will produce a specific error. Function (error) => output. Good way to fully test coverage of a broad range of errors running through the same function

Actix-Web provides several "extractors" to get information out of requests. Via Path, Query, Json, Form data, etc. The Form trait itself is a wrapper, but what really matters is specific Form's implementation of the `from_request` method, which must be implemented by all "extractors" The from-request method runs a deserialized parser across the byte stream to extract the data.

When a handler uses an "extractor", Actix will call `from_request` to see if it can successfully parse the incoming request into the data that's being expected. If successful parse, Actix immediately returns 200 and if not then 400 - Regardless of whatever code you put into a function. Response codes in actix directly reflect success or failure of `from_requests` ability to parse the data.

Generics don't have performance hindrence despite not knowing types beforehand. Compiler will actually create copies of the generic function but replacing generic type parameters with concrete types (aka monomorphization). This is referred to as zero-cost abstracting... use higher-level language contracts and writing easy-to-read code for humans.. without having to compromise on the quality of the final artifact.

Cloud-native aplications are distributed, and therefore must have many replicas (and not reliant on local filesystems). This is why Cloud-native applications are usually stateless (no preservation of state outside of one-time transactions). Instead, their persistence needs are delegated to specialized external systems - databases.

Database types: document-store (MongoDB), key-value store (DynamoDB), graph (neo4j), RAM as primary storage (Redis). Optimized for analytical queries via columnar storage (AWS Redshift).

When in doubt, use relational database, and if no reason to expect MASSIVE scale, use PostgresQL. Newer databases like AWS Aurora, Google Spanner, Cockroach DB meant for way massive scale above traditional SQL databases. Otherwise.. just use PostgreSQL - batttle tested, sidely supported, easy to run locally.

PostgreSQL options in Rust... 
1. Compile time safety. Most programming languages mistakes will be found out during runtime and costly to reject query. Instead, sqlx and diesel check query works at COMPILE TIME. Tokio-postgres checks at run-time. sqlx checks via a live connection to database during compile, while diesel saves a representaion of database schema offline.

2. Query-Interface. sqlx and tokio-postgres just use SQL. Diesel own language interface.

3. Async support. Database is not sitting next to your application on the same physical machine most of time. To run queries, you have to perform network calls.. asychronous database drivers will not reduce how long it takes to process a single query, but it enables application to leverage all CPU cores to perform other meanigful work while waiting for the database to return results.

UNIQUE (and contraints in general) slows down writes in a database because index must be updated on every INSERT / UPDATE / DELETE and you need to scan across other data to ensure consistency with the constraints.

PgConnection doesn't implement clone because it sits on top of a non-cloneable system resource, a TCP connection with Postgres. Instead.. wrap the connection in an ARC pointer that IS cloneable. Pull the reference from ARC using get_ref() when you're ready to use it (when binding execute to sqlx::query! )

Still, executor of sqlx::query! requires an & mut PgConnect to enforce guarantee of not allowing mutiple queries to conncurently over the same database connection.  Yet web::data (which feeds us a global application state across instances) will never give us **mutable** access to application state.

Within sqlx, PgPool ALSO implement Executor trait. Allows for a pool of connections to work together in a consumer group. If no connection available, wait until one frees up. A SINGLE slow query won't slow down all connections, and you can have multiple connections. Use PgPool instead of PgConnection given that ActixWeb HttpServer spins up multiple instances of App to serve out.

## Chapter 4 : Telemetry

At runtime, you will surely encounter scenarios that we have not tested for or even thought about when designing the application. Unknown unknowns are peculiar failure modes of the specific system we are working on. THey are problems at the crossroads between software, underlying OS, hardware, development process, and randomness from "outside world". Often emerge when (1) pushed outside usual operating conditions [spike in traffic], (2) multiple component failures, (3) changes that move system equilibrium [tuning a retry policy], (4) no changes have been introduced for a long time [memory leaks]. All these issues often impossible to reproduce outside of the live environment.

Telemetry data: information about our running application is collected automatically and can be later inspected to answer questions about state of the system at a certain point in time. Observability is about being able to ask arbitrary questions about your environment without having to know ahead of time what you wanted to ask.

When rust forces you to implement yourself, it's not trying to prescibe how you should do things. 

Instrumentation is naturally a local decision. But what about global decisions at the application level - what to do with log records. 

Facade pattern - just suggest virtual interface but concrete method must be implemented yoruself. 

Logged metrics should reflect user / trouble tickets. "I tried loggin with email X and Y time." Should help in investigation and isolation of problem

Logs must correlate to all other logs related to the same request. Many processes at once will jumble the output.

Problem with logging is that context is lost between child and parent level. Confusing to think about which level of abstraction is appropriate. Logs are wrong abstraction. Log statements are isolated events happening at a defined moment in time. Instead, you might be interested in tree-like processing pipeline (that has duration, context [variables you are tracking]).

The better abstraction is tracing. Allows libraries and pplications to record structured events with additional information about temporality and causality. Use a `Span` object rather than a log message.. a span has beginning and end time, and may be entered and exited by flow of execution. Better mapping of graph / flow of execution.

% symbol denotes using Display implementation for logging purposes.

Entered is a guard... it will register downstream spans and own the children. Resource Acquistition is Initialization. Keep track of lifetime of all variables. And when they go out of scope, a call to destructor: Drop is automatically called.. this will take care of releasing resources owned by a variable.

Debug output from trace will have TRACE steps -> enter <- exit -- close. INFO represents log events, while TRACE steps represent SPAN events.

There's a difference between exit and closed. Polling will continuously enter and exit without fully closing the trace connection.

Subscriber object will trace through the program.. but is built up with layers.. to filter out which levels you want, to store the logs (into searchable JSON format), and where to output (std::out) from storage format.

Tests will re-initialize things multiple times. Use once_cell dependency package to wrap the function around an object that will be called only once.

Secrecy objects disables display formats of Strings so it forces you to encode and decode things as a Secret, rather than a regular thing (but it doesn't mess around with Deserialization). Exposure / Printing must be done manually rather than automatically.

Ultimately still need tracing-actix package to have a global request-id at the App level (to include App level request tracing). It automatically generates the request-id at the app level, rather than the function level (wrong place to define it)

## Chapter 5 : Deploying to Production

Local deployment environment vs. production environment serve two very different purposes. Local machines are multi-purpose workstations. Production environments, instead have a much more narrow focus: making software available to users. Anything not strictly related to that goal is either a waste of resource, at best, or a security liability at worst.

Manually creating an environment is very hard. Software likely to make assumptions about capabilities exposed by underlying OS, availability of other software (python interpreter), or on configuration (root permissions?). Run into troubles as versions drift and subtle inconsistencies come up.

Ensure software runs correctly by **tightly controlling the environment it is being executed into.** what if instead of shipping code to production, you could ship a self-contained environment that included your application. Best if environment itself can be **specified as code** to ensure reproducibility

Docker is a recipe for your application environment. They are organized in layers: you start from a base image (usually an IS enriched with a programming language toolchain).. and then you execute a series of commands (COPY, RUN, etc), to build the environment you need.

WORKDIR / app (equivalent to cd app, and make the app folder)
Run apt update && apt install lld clang -y
COPY . . (copy all files from our working environment to Docker image)
RUN cargo build --release
ENTRYPOINT ["./target/release/zero2prod"] (run this binary when you execute 'docker run')

Build docker image with `docker build --tag zero2prod --file Dockerfile .` The `.` is for current directory to be used as build context so `COPY . app ` would copy everything in current directory into app directory of Docker image.

sqlx checks all queries against a live database model at compile time. Need to enable offline mode and creation of a cached json file that stores cached version of query metadata 

connect_lazy allows you to try to connect only when you actually try to make the query

By default, Docker images do not expose their ports to the underlying host machine. Need to do it explicitly using the -p flag.

Specifying 127.0.0.1 as host instructs the application to only accept connections coming from the same machine.. need to use 0.0.0.0 as host to instruct application to accept connections from any network interface, not just the local one. BUt there are security implications so use 127 for local and 0.0 for Docker image.

To configure things properly, need to have hierarchical approach. Base configuration file for values shared across local and production environment. A separate collection of environment-specific configuration files (like one for local and one for production). And finally an environmental variable APP_ENVIRONMENT to actually determine the running environment (production or local).. so you'll have a base.yaml, local.yaml and production.yaml. The main difference between local and production yaml will be application host url 127 vs. 0

Set the APP_ENVIRONMENT variable to production within the docker file. 

### Docker Image Optimization

Docker doesn't get built on server, but rather it pulls the docker image, so reducing file size is important.

Remove anything not needed for compile in .dockerignore file. Binaries are also statically inked so you don't even need the source code. Leverage multi-stage builds (a) builder stage to generate the compiled binary and (2) runtime stage to run it. Everything from builder stage gets discarded

Layer caching. if nothing has changed up to a certain checkpoint no need for rebuilding that portion of the container. Therefore **anything that refers to files that are changing often (e.g. source code) should appear as late as possible, while dependencies should appear early on as they do not change a lot and are expensive**

Have a stage to build the recipe file (to list dependencies), second cache the dependencies, third, build the binary, fourth create the runtime environment (on debian slim).

Digital ocean upload is dome through doctl command line interface. Create a spec.yaml with all the configuration settings. Link to Github (which will be monitored for continuous deployment).. and then run doctl apps update APP-ID -spec=spec.yaml

turn on SSL settings for database in production mode (and turn off for local).

Run the sqlx migration on the live database server once its up.

## Chapter 6 : Input Validation

If you let invalid input slip by and go into the database, it will only give you problems further down the line.

Form inputs are a primary attack target. Best to have a layered security approach at different levels (input validation, parameterized queries, escaping invalid characters). Reject anything longer than 256 characters. Reject troublesome characters that are common in URLs, SQL Queries and HTML fragments.. but not in names. Forbidding them raises the complexity bar for SQL injection and phishing attempts

Local vs. global approach to validation. If you take a local approach, you need to repeat the validation process at every part of the system, which doesn't scale. If you're putting validation into a function format.. you're not actually storing structural data about the input.. forcing a validation at every check point of the system.

**Need a PARSING FUNCTION that converts unstructured input to a more structured output, an output that structurally guarantees that the invariants we care about hold from that point onwards.** 

Effectively, use Rust type system as a means to validate. Make incorrect usage pattern unrepresentatble, by construction. THe more expressive the type system of a programming language, the tighter you can constrain code to only be able to represent states that are valid in the domain we are working in.

Ownership system implies only three methods of ownership when "exposing" a value.. (1) you consume it too, taking ownership, (2) make it mutable, but provides reference exclusivity, (3) exposed read-only sharable reference. inner_ref or as_ref() do this.

Panics in Rust are used to deal with unrecoverable errors. Failure mores that were not expected like running out of memory or full disk. If panic in response to user input, there is an application bug. But if it's something pretty imaginable (like invalid input) and you want to handle.. Use Results, which is error handling mechanism built into Rust. 

Result is used as the return type for fallible operations. If success Ok(T) is returned. Otherwise, Err(E). Rust type system forces you to deal with both the happy path and the unhappy path. Errors, when combined with enums, are great building blocks for a robust error handling story.

Put unit tests alongside type-driven domain handling (i.e. pass and fail bad inputs / good inputs) to fully test parsing.

The ? operator says.. if let Error = TRY SOMETHING then error. This allows for early return if there's an error, and if success, then TRY SOMETHING will create the desired side effect anyways. ? can only be used with a Result.

When handling error messages you want specificity in what KIND of error and what caused it.

Property based testing - randomly generate things that "should be" valid. Significantly increase range of inputs to be validated.. increases confidence in correctness of code but not 100% exhaustive.. but it's the best you can do.

Separation of concerns. Use parsing to convert a type from "wire format" (url encoded data from HTML form) to domain model (NewSubscriber) used in app.

try_into and try from is essentially trait that implements a parsing function 
<br>

## Chaper 7 : Deployment Modifications

<br>Several instances of server app gets spawned. However, to serve the app, it's best to just have a single instance of a client making API requests (as opposed to a clone of a client for every instance). You want a clone of a reference pointer rather than clone of client instance, and these pointers to be pointing to a shared instance used across all spawned App instances

Testing clients (that make requests) need a mock counterparty (server) for unit tests, rather than testing against an actual public API.

Using randomized data in tests conveys a specific message: do not pay attention to these inputs, their values do not influence the outcome of the test, that's why they are random

Mock interface from wiremock uses expect(1) that will verify once it goes out of scope, and thereforea separation assertion isn't written out. The mock should receive exactly one request that matches the conditions set by the mock.

When interacting with API, be careful about subtle differences in naming convention (Pascal case) for certain parameters.

Use pointers whereover possible rather than replicating and cloning values. Use &'a str (with lifetime 'a) instead of String.

There's a subtle difference between testing whether a connection was successful (default behavior), or testing an error based on returned status code from the server (200 vs 500 code). you want error_for_status, not 'error'

Automated tests reduce the risk associated with changes to an existing codebase. Tests act as documentation as well. Shows how the code is supposed to behave and what scenarios are considered relevant enough to have dedicated tests for. Good tests build technical leverage, but writing tests takes time. Additionally, if you do not actively invest in the health of the test suite, it will rot over time. Test code is still code.

Don't jumble code together in same document just because it leverages the same setup. Refactor it, but don't "pull in helpers" into individual test files.. rather start with one main scope (a test executable), and then add in sub-modules into tests/api/main.rs .. this allows for recursive structure in case functions like health_check, subscriptions, etc need to be further broken down. Additionally these sub-modules can now pull in specific functions referenced within main (like a helper module with use crate::helpers::FUNCTION) that comes from having a single main executable.

Load balancers support adding (and removing) backends dynamically, acting as one continuous "front" for the user, while background can change.. allows for horizontal scaling to match demand load, but can also implement rolling updates when deploying features. Health checks (on what instances are working properly) can be done passively (look at distribution of status codes / latency for each backend to determine health.. measure when user fires on a "lazy" basis), or active (regularly scheduled heartbeat checks).

Load balancer coordinates and ensures redundancy of backend services.

TO ensure high avilability, applications need to be stateless (context kept to one-time transactions). Instead, persistence concerns are delegated to databases. This allows for the use of load balancers because it doesn't matter which instance of the replica you're using (state doesn't matter). But they're all talking tot he same database.. 

Think of a database as a single gigantic global variable.

Migrating and changing schema for databases is hard. Old applications will naturally have a different schema interface that is incompatible with new database, and vice versa, especially during migration. Need to phase in changes (that are backwards compatible) with multiple stages..

Migrate the database with new columns that are OPTIONAL.. then deploy the new code that leverages the new columns.. backfill old data  entries for new column with default values.. put in the NOT NULL constraints.. and app whould now be running on steady state basis.

If you have multiple database transactions / queries within a single user request, you're going to need TRANSACTIONS (atomic).. Transactions start with BEGIN .. instructions in between.. and then a COMMIT.. (or a ROLLBACK) to avoid any states that are invalid / "in between" the individual queries. Either all in, or all out. 

sqlx provides a transaction struct by calling pool.begin().. submit the query with execute(transaction).. but you'll need an explicit transaction.commit() call, or else the transaction defaults to a rollback when it falls out of scope.
## Chapter 9

Data stored in our Postgres instance creates a temporal coupling between old and new versions of our application.

Allow first for more leniency.. update the code, retroactively fill in the blanks, and make more rigorous requirements again.


## Chapter 10

Cross site scripting: Query parameters not private, URL can be tweaked to feed bad input to server.

Message Authentification Codes: Add a message tag to verify integrity and origin. HMACs are hash based authentification codes. Insert HMAC alongside message within the header code. 

Cookie is another side channel invisible to the browser history. One time use cookies (with no ttl) are called flash messages. Cookies are set by attaching a special HTTP header to the response - Set-Cookie.

When it comes to durability, there are two types of cookies: session cookies and persistent cook- ies. Session cookies are stored in memory - they are deleted when the session ends (i.e. the browser is closed). Persistent cookies, instead, are saved to disk and will still be there when you re-open the browser. Set the max age

Use Redis as session token store as durability of RAM doesn't matter in this use case. For short-lived key value store Redis is good solution with speed boost.

## Chatper 11 : Fault Tolerant Workflows

Use idempotency key to ensure that multiple calls on retry have just one effect (i.e. no duplicate requests)

Use forward recovery with background workers (that work up to point of pushing final request step to API) to allow for self-healing recovery process should things go wrong. 