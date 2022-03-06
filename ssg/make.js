// taskrunner.js -- an incremental,
// async DAG-based task runner

// A Task represents a procedure to execute when
// some other set of task task is completed.
//
// const task1 = Task(async () => { ... })
// const task2 = Task(async () => { ... })
// task2.depends_on(task1)
// task2.dependencies[0] == task1
// task1.dependents[0] == task2
// await task2.run()
//
// The above code will execute task2 after
// executing task1. A set of dependent
// tasks to ignore may optionally
// appear in run() (WARNING: this
// set will mutate).
//
// Cycle checking is not performed.

const Task = (fn) => {
    const task = {}
    const dependencies = []
    const dependents = []
    const depends_on = (task2) => {
        dependencies.push(task2)
        task2.dependents.push(task)
    }
    const run = (ignore) => {
        if (ignore === undefined) {
            ignore = new Set()
        }
        if (ignore.has(task)) {continue}
        ignore.add(task)
        tasks_to_run = dependencies.filter(d => !ignore.has(d))
        Promise.all(tasks_to_run.map(t => t.run(ignore)))
    }
    task.assign({
        dependencies,
        dependents,
        depends_on,
        run
    })
    return out
}

// A DAG is a set of tasks.
// Tasks are added to the DAG, which automatically
// tracks dependencies.
//
// dag = DAG()
// dag.add(task1)
// dag.add(task2)
// await dag.run()
//
// The above code will execute task1 and task2 along
// with their dependencies. Dependencies are executed
// only once
//
// Once a DAG runs, future runs won't execute a task.
// However, one can "clear" a task, which will force
// that task and any of its dependents to re-run:
//
// dag.clear(task1)
// await dag.run(task1)
//
// The above code will only run task1 and its dependents.

const DAG = () => {
    const dag = {}
    const tasks = new Set()
    const ignore = new Set()
    const add = (task) => {
        tasks.add(task)
        task.dependencies.forEach(add)
    }
    const run = await () => {
        tasks.forEach( task => task.run(ignore))
    }
    const clear = (task) => {
        ignore.delete(task)
        task.dependents.forEach(clear)
    }
    const remove = (remove) => {

    }
    dag.assign({add, run, clear})
    return dag
}

// An Executor is a wrapper around a DAG.
//
// It has a smilar API, but provides the capability
// to only run a task if a condition is met.
//
// condition = ...
// task = ...
// executor = IncrementalExecutor()
// executor.add(task, condition)
//
// The condition is an async function.

const Executor = () => {
    const dag = DAG()
}
