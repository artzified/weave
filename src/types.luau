type ActorPoolProps = {
	actors: { Actor },
	actorStorage: Instance,
	handshakeBindable: BindableEvent,
	populateCallback: ((Actor) -> ())?,
	count: number,
}

type ActorPoolMethods = {
	DoHandshake: (self: ActorPool, message: string, ...any) -> (),
	Populate: (self: ActorPool, worker: Script | LocalScript, actorCount: number) -> (),
	DispatchAll: (self: ActorPool, message: string, ...any) -> (),
	DispatchBatched: (self: ActorPool, message: string, threadCount: number, batchSize: number, ...any) -> (),
	OnPopulate: (self: ActorPool, callback: ((Actor) -> ())?) -> (),
	Destroy: (self: ActorPool) -> (),
}

export type ActorPool = setmetatable<ActorPoolProps, { __index: ActorPoolMethods }>

type ClusterProps = {
	pool: ActorPool,
	registeredJobs: { [string]: Job },
}

type ClusterMethods = {
	DefineJob: (self: Cluster, name: string) -> Job,
	Destroy: (self: ActorPool) -> (),
}

export type Cluster = setmetatable<ClusterProps, { __index: ClusterMethods }>

type JobProps = {
	pool: ActorPool,
	bindable: BindableEvent,
	name: string,
	batchSize: number?,
}

type JobMethods = {
	SetReadonlyData: (self: Job, key: string | number, value: any) -> Job,
	Dispatch: (self: Job, threadCount: number, callback: ((data: { any }) -> ...any)?, ...any) -> (),
	DispatchDeferred: (self: Job, threadCount: number, callback: ((data: { any }) -> ...any)?, ...any) -> (),
	Linear: (self: Job) -> Job,
	Batched: (self: Job, batchSize: number) -> Job,
	Destroy: (self: Job) -> (),
}

export type Job = setmetatable<JobProps, { __index: JobMethods }>

return 0
