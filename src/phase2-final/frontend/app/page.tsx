"use client";

import { useState, useEffect, useCallback, useMemo } from "react";
import {
  format, startOfMonth, endOfMonth, startOfWeek, endOfWeek,
  addDays, isSameMonth, isSameDay, isToday, addMonths, subMonths,
  parseISO, startOfDay,
} from "date-fns";
import {
  ChevronLeft, ChevronRight, Plus, X, Check, Pencil, Trash2,
  Calendar, Clock, Flag, AlignLeft, CheckSquare2,
} from "lucide-react";
import { fetchAPI } from "./modules/api";

// ── Domain Types ──────────────────────────────────────────────────────────────
type Priority = "high" | "normal" | "low";

interface Task {
  id: number;
  title: string;
  description?: string;
  priority: Priority;
  due_at: string;       // ISO 8601 string from backend
  status: "open" | "done";
  created_at?: string;
  updated_at?: string;
  completed_at?: string | null;
}

interface PriorityConfig {
  value: Priority;
  label: string;
  cls: string;
}

interface TaskModalProps {
  defaultDate: Date | null;
  editTask: Task | null;
  onClose: () => void;
  onSaved: () => void;
}

interface TaskCardProps {
  task: Task;
  onToggle: (task: Task) => void;
  onEdit: (task: Task) => void;
  onDelete: (task: Task) => void;
}

interface DayCellProps {
  date: Date;
  currentMonth: Date;
  tasks: Task[];
  selected: Date | null;
  onClick: (date: Date) => void;
}

interface DayPanelProps {
  date: Date | null;
  tasks: Task[];
  onClose: () => void;
  onAddTask: () => void;
  onToggle: (task: Task) => void;
  onEdit: (task: Task) => void;
  onDelete: (task: Task) => void;
}

interface ModalState {
  mode: "add" | "edit";
  task?: Task;
  date?: Date;
}

interface TasksResponse {
  items?: Array<{ task?: Task } | Task>;
}

// ── Constants ──────────────────────────────────────────────────────────────────
const WEEKDAYS: string[] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const PRIORITIES: PriorityConfig[] = [
  { value: "high",   label: "🔴 High",   cls: "badge-high" },
  { value: "normal", label: "🔵 Normal", cls: "badge-normal" },
  { value: "low",    label: "🟣 Low",    cls: "badge-low" },
];

// ── Helper: build calendar grid days ─────────────────────────────────────────
function buildCalendarDays(monthDate: Date): Date[] {
  const start = startOfWeek(startOfMonth(monthDate), { weekStartsOn: 0 });
  const end   = endOfWeek(endOfMonth(monthDate), { weekStartsOn: 0 });
  const days: Date[] = [];
  let cur = start;
  while (cur <= end) {
    days.push(cur);
    cur = addDays(cur, 1);
  }
  return days;
}

// ── Task Modal ────────────────────────────────────────────────────────────────
function TaskModal({ defaultDate, editTask, onClose, onSaved }: TaskModalProps): React.JSX.Element {
  const isEdit = !!editTask;
  const defaultDue = defaultDate
    ? format(defaultDate, "yyyy-MM-dd") + "T09:00"
    : format(new Date(), "yyyy-MM-dd") + "T09:00";

  const [title, setTitle]   = useState<string>(isEdit ? editTask.title : "");
  const [desc, setDesc]     = useState<string>(isEdit ? (editTask.description ?? "") : "");
  const [priority, setPri]  = useState<Priority>(isEdit ? (editTask.priority ?? "normal") : "normal");
  const [dueAt, setDueAt]   = useState<string>(
    isEdit && editTask.due_at
      ? format(parseISO(editTask.due_at), "yyyy-MM-dd'T'HH:mm")
      : defaultDue
  );
  const [saving, setSaving] = useState<boolean>(false);
  const [error, setError]   = useState<string>("");

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>): Promise<void> => {
    e.preventDefault();
    if (!title.trim()) { setError("Title is required"); return; }
    setSaving(true);
    setError("");
    try {
      const body = {
        title: title.trim(),
        description: desc.trim(),
        priority,
        due_at: new Date(dueAt).toISOString(),
      };
      if (isEdit) {
        await fetchAPI(`/tasks/${editTask.id}`, { method: "PATCH", body: JSON.stringify(body) });
      } else {
        await fetchAPI("/tasks", { method: "POST", body: JSON.stringify(body) });
      }
      onSaved();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (): Promise<void> => {
    if (!confirm("Delete this todo?")) return;
    try {
      await fetchAPI(`/tasks/${editTask!.id}`, { method: "DELETE" });
      onSaved();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-card" onClick={(e: React.MouseEvent<HTMLDivElement>) => e.stopPropagation()}>
        <div className="modal-header">
          <span className="modal-title">{isEdit ? "Edit Todo" : "New Todo"}</span>
          <button className="btn-icon" onClick={onClose}><X size={18} /></button>
        </div>
        <form className="modal-body" onSubmit={handleSubmit}>
          {error && <div className="form-error">{error}</div>}

          <div className="field-group">
            <label className="field-label">
              <CheckSquare2 size={11} style={{ display: "inline", marginRight: 4 }} />
              Title
            </label>
            <input
              className="field-input"
              value={title}
              onChange={(e: React.ChangeEvent<HTMLInputElement>) => setTitle(e.target.value)}
              placeholder="What needs to be done?"
              autoFocus
            />
          </div>

          <div className="field-row">
            <div className="field-group">
              <label className="field-label">
                <Clock size={11} style={{ display: "inline", marginRight: 4 }} />
                Due date &amp; time
              </label>
              <input
                className="field-input"
                type="datetime-local"
                value={dueAt}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setDueAt(e.target.value)}
              />
            </div>
            <div className="field-group">
              <label className="field-label">
                <Flag size={11} style={{ display: "inline", marginRight: 4 }} />
                Priority
              </label>
              <select
                className="field-input select-styled"
                value={priority}
                onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setPri(e.target.value as Priority)}
              >
                {PRIORITIES.map((p) => (
                  <option key={p.value} value={p.value}>{p.label}</option>
                ))}
              </select>
            </div>
          </div>

          <div className="field-group">
            <label className="field-label">
              <AlignLeft size={11} style={{ display: "inline", marginRight: 4 }} />
              Description (optional)
            </label>
            <textarea
              className="field-input"
              value={desc}
              onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setDesc(e.target.value)}
              placeholder="Add details, notes, or links…"
              rows={3}
            />
          </div>

          <div className="modal-actions">
            {isEdit && (
              <button type="button" className="btn-danger" onClick={handleDelete}>
                <Trash2 size={14} style={{ marginRight: 4 }} />Delete
              </button>
            )}
            <button type="button" className="btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn-primary" disabled={saving}>
              {saving ? "Saving…" : (isEdit ? "Save changes" : "Add Todo")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

// ── Task Card ─────────────────────────────────────────────────────────────────
function TaskCard({ task, onToggle, onEdit, onDelete }: TaskCardProps): React.JSX.Element {
  const isDone = task.status === "done";
  const pri    = PRIORITIES.find((p) => p.value === (task.priority ?? "normal"));

  return (
    <div className={`task-card ${isDone ? "done-card" : ""}`}>
      <div className="task-card-row">
        <button
          className={`task-checkbox ${isDone ? "checked" : ""}`}
          onClick={() => onToggle(task)}
          title={isDone ? "Mark open" : "Mark done"}
        >
          {isDone && <Check size={11} color="#0f172a" strokeWidth={3} />}
        </button>
        <div className="task-content">
          <div className="task-title">{task.title}</div>
          {task.description && (
            <div className="task-desc">{task.description}</div>
          )}
          <div className="task-meta">
            {task.due_at && (
              <span className="task-time">
                <Clock size={10} />
                {format(parseISO(task.due_at), "HH:mm")}
              </span>
            )}
            <span className={`task-badge ${pri?.cls ?? "badge-normal"}`}>
              {task.priority ?? "normal"}
            </span>
            <span className={`task-badge ${isDone ? "badge-done" : "badge-open"}`}>
              {isDone ? "done" : "open"}
            </span>
          </div>
        </div>
      </div>
      <div className="task-actions">
        <button className="task-action-btn" title="Edit" onClick={() => onEdit(task)}>
          <Pencil size={12} />
        </button>
        <button className="task-action-btn danger" title="Delete" onClick={() => onDelete(task)}>
          <Trash2 size={12} />
        </button>
      </div>
    </div>
  );
}

// ── Day Cell ──────────────────────────────────────────────────────────────────
function DayCell({ date, currentMonth, tasks, selected, onClick }: DayCellProps): React.JSX.Element {
  const isCurrentMonth = isSameMonth(date, currentMonth);
  const isT  = isToday(date);
  const isSel = selected !== null && isSameDay(date, selected);
  const MAX_PILLS = 3;

  const visibleTasks = tasks.slice(0, MAX_PILLS);
  const hiddenCount  = tasks.length - MAX_PILLS;

  const cls = [
    "cal-day",
    !isCurrentMonth ? "other-month" : "",
    isT             ? "today"       : "",
    isSel           ? "selected"    : "",
    tasks.length > 0 ? "has-tasks"  : "",
  ].filter(Boolean).join(" ");

  return (
    <div className={cls} onClick={() => onClick(date)}>
      <div className="cal-day-header">
        <span className="cal-day-num">{format(date, "d")}</span>
        {tasks.length > 0 && (
          <span className="cal-day-count">{tasks.length}</span>
        )}
      </div>
      <div className="cal-task-pills">
        {visibleTasks.map((t) => {
          const pillCls = [
            "cal-task-pill",
            t.status === "done" ? "done" : "open",
            t.priority === "high" && t.status !== "done" ? "high" : "",
          ].filter(Boolean).join(" ");
          return (
            <div key={t.id} className={pillCls} title={t.title}>
              {t.title}
            </div>
          );
        })}
        {hiddenCount > 0 && (
          <div className="cal-task-pill more">+{hiddenCount} more</div>
        )}
      </div>
    </div>
  );
}

// ── Day Panel ─────────────────────────────────────────────────────────────────
function DayPanel({ date, tasks, onClose, onAddTask, onToggle, onEdit, onDelete }: DayPanelProps): React.JSX.Element {
  const open    = tasks.filter((t) => t.status !== "done");
  const done    = tasks.filter((t) => t.status === "done");
  const ordered = [...open, ...done];

  return (
    <div className={`day-panel ${date ? "open" : ""}`}>
      {date && (
        <>
          <div className="panel-header">
            <div>
              <div className="panel-date-label">
                {format(date, "EEEE")}
              </div>
              <div className="panel-date-sub">
                {format(date, "MMMM d, yyyy")}
                {isToday(date) && (
                  <span style={{ marginLeft: 6, color: "var(--accent)", fontWeight: 600 }}>
                    — Today
                  </span>
                )}
              </div>
            </div>
            <button className="panel-close" onClick={onClose}><X size={18} /></button>
          </div>

          <button className="panel-add-btn" onClick={onAddTask}>
            <Plus size={16} />
            Add todo for this day
          </button>

          <div className="panel-tasks">
            {ordered.length === 0 ? (
              <div className="panel-empty">
                <div className="panel-empty-icon">📋</div>
                <div>No todos for this day</div>
                <div style={{ marginTop: 4, fontSize: "0.78rem", color: "var(--text-dim)" }}>
                  Click &quot;Add todo&quot; to get started
                </div>
              </div>
            ) : (
              ordered.map((task) => (
                <TaskCard
                  key={task.id}
                  task={task}
                  onToggle={onToggle}
                  onEdit={onEdit}
                  onDelete={onDelete}
                />
              ))
            )}
          </div>
        </>
      )}
    </div>
  );
}

// ── Main Page ─────────────────────────────────────────────────────────────────
export default function HomePage(): React.JSX.Element {
  const [currentMonth, setCurrentMonth] = useState<Date>(new Date());
  const [selectedDay,  setSelectedDay]  = useState<Date | null>(null);
  const [allTasks,     setAllTasks]     = useState<Task[]>([]);
  const [loading,      setLoading]      = useState<boolean>(true);
  const [modal,        setModal]        = useState<ModalState | null>(null);

  // Load all tasks once and keep in state
  const loadTasks = useCallback(async (): Promise<void> => {
    setLoading(true);
    try {
      const data = await fetchAPI<TasksResponse | Task[]>("/tasks");
      const raw = Array.isArray(data) ? data : (data as TasksResponse).items ?? [];
      const items = raw.map((item) => {
        if ("task" in item && item.task !== undefined) return item.task;
        return item as Task;
      });
      setAllTasks(items);
    } catch (err) {
      console.error("loadTasks:", err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void loadTasks(); }, [loadTasks]);

  // Group tasks by day key "yyyy-MM-dd"
  const tasksByDay = useMemo<Record<string, Task[]>>(() => {
    const map: Record<string, Task[]> = {};
    for (const task of allTasks) {
      if (!task.due_at) continue;
      const key = format(parseISO(task.due_at), "yyyy-MM-dd");
      if (!map[key]) map[key] = [];
      map[key].push(task);
    }
    return map;
  }, [allTasks]);

  const calDays = useMemo<Date[]>(() => buildCalendarDays(currentMonth), [currentMonth]);

  // Tasks for selected day panel
  const selectedDayTasks = useMemo<Task[]>(() => {
    if (!selectedDay) return [];
    const key = format(selectedDay, "yyyy-MM-dd");
    return (tasksByDay[key] ?? []).sort((a, b) => {
      if (a.status !== b.status) return a.status === "done" ? 1 : -1;
      return a.due_at && b.due_at ? a.due_at.localeCompare(b.due_at) : 0;
    });
  }, [selectedDay, tasksByDay]);

  // Stats
  const stats = useMemo(() => {
    const open = allTasks.filter((t) => t.status !== "done").length;
    const done = allTasks.filter((t) => t.status === "done").length;
    const today = allTasks.filter(
      (t) => t.due_at && isSameDay(parseISO(t.due_at), new Date())
    ).length;
    const overdue = allTasks.filter(
      (t) => t.status !== "done" && t.due_at &&
        parseISO(t.due_at) < startOfDay(new Date())
    ).length;
    return { open, done, today, overdue };
  }, [allTasks]);

  // Toggle task done/open
  const handleToggle = async (task: Task): Promise<void> => {
    const newStatus = task.status === "done" ? "open" : "done";
    try {
      await fetchAPI<Task>(`/tasks/${task.id}`, {
        method: "PATCH",
        body: JSON.stringify({ status: newStatus }),
      });
      setAllTasks((prev) =>
        prev.map((t) =>
          t.id === task.id
            ? { ...t, status: newStatus, completed_at: newStatus === "done" ? new Date().toISOString() : null }
            : t
        )
      );
    } catch (err) {
      console.error("toggle:", err);
    }
  };

  const handleDelete = async (task: Task): Promise<void> => {
    if (!confirm("Delete this todo?")) return;
    try {
      await fetchAPI(`/tasks/${task.id}`, { method: "DELETE" });
      setAllTasks((prev) => prev.filter((t) => t.id !== task.id));
    } catch (err) {
      console.error("delete:", err);
    }
  };

  const handleSaved = (): void => {
    setModal(null);
    void loadTasks();
  };

  const openAddModal = (date: Date | null): void => {
    setModal({ mode: "add", date: date ?? selectedDay ?? new Date() });
  };

  const openEditModal = (task: Task): void => {
    setModal({ mode: "edit", task });
  };

  const handleDayClick = (date: Date): void => {
    setSelectedDay((prev) =>
      prev !== null && isSameDay(prev, date) ? null : date
    );
  };

  return (
    <div className="app-root">
      {/* ── Header ──────────────────────────────────────────────── */}
      <header className="header">
        <div className="header-brand">
          <div className="header-logo">T</div>
          <div>
            <div className="header-title">TodoApp</div>
            <div className="header-subtitle">K3s · Woodpecker CI/CD · Docker Hub</div>
          </div>
        </div>

        <nav className="header-nav">
          <button className="header-nav-btn active">
            <Calendar size={13} style={{ display: "inline", marginRight: 4 }} />
            Calendar
          </button>
        </nav>

        <div className="header-actions">
          <button className="btn-add-task" onClick={() => openAddModal(selectedDay)}>
            <Plus size={15} />
            New Todo
          </button>
        </div>
      </header>

      {/* ── Stats bar ───────────────────────────────────────────── */}
      <div className="stats-bar">
        <div className="stat-item">
          <span className="stat-dot" style={{ background: "var(--accent)" }} />
          <span className="stat-value">{stats.open}</span>
          &nbsp;open
        </div>
        <div className="stat-item">
          <span className="stat-dot" style={{ background: "var(--green)" }} />
          <span className="stat-value">{stats.done}</span>
          &nbsp;done
        </div>
        <div className="stat-item">
          <span className="stat-dot" style={{ background: "var(--amber)" }} />
          <span className="stat-value">{stats.today}</span>
          &nbsp;today
        </div>
        {stats.overdue > 0 && (
          <div className="stat-item">
            <span className="stat-dot" style={{ background: "var(--red)" }} />
            <span className="stat-value" style={{ color: "var(--red)" }}>{stats.overdue}</span>
            &nbsp;overdue
          </div>
        )}
        <div className="stat-item" style={{ marginLeft: "auto" }}>
          <span style={{ color: "var(--text-dim)", fontSize: "0.75rem" }}>
            {loading ? "Syncing…" : `${allTasks.length} total todos`}
          </span>
        </div>
      </div>

      {/* ── Main area ───────────────────────────────────────────── */}
      <div className="main-area">

        {/* ── BIG Calendar ──────────────────────────────────────── */}
        <div className="calendar-container">

          {/* Month Nav */}
          <div className="cal-nav">
            <h1 className="cal-nav-title">
              {format(currentMonth, "MMMM yyyy")}
            </h1>
            <div className="cal-nav-controls">
              <button className="cal-today-btn" onClick={() => {
                setCurrentMonth(new Date());
                setSelectedDay(new Date());
              }}>
                Today
              </button>
              <button className="cal-nav-btn" onClick={() => setCurrentMonth(subMonths(currentMonth, 1))}>
                <ChevronLeft size={16} />
              </button>
              <button className="cal-nav-btn" onClick={() => setCurrentMonth(addMonths(currentMonth, 1))}>
                <ChevronRight size={16} />
              </button>
            </div>
          </div>

          {/* Weekday headers */}
          <div className="cal-weekdays">
            {WEEKDAYS.map((d, i) => (
              <div key={d} className={`cal-weekday ${i === 0 || i === 6 ? "weekend" : ""}`}>
                {d}
              </div>
            ))}
          </div>

          {/* Grid */}
          <div className="cal-grid">
            {calDays.map((date) => {
              const key   = format(date, "yyyy-MM-dd");
              const tasks = tasksByDay[key] ?? [];
              return (
                <DayCell
                  key={key}
                  date={date}
                  currentMonth={currentMonth}
                  tasks={tasks}
                  selected={selectedDay}
                  onClick={handleDayClick}
                />
              );
            })}
          </div>
        </div>

        {/* ── Right Panel ───────────────────────────────────────── */}
        <DayPanel
          date={selectedDay}
          tasks={selectedDayTasks}
          onClose={() => setSelectedDay(null)}
          onAddTask={() => openAddModal(selectedDay)}
          onToggle={handleToggle}
          onEdit={openEditModal}
          onDelete={handleDelete}
        />
      </div>

      {/* ── Task Modal ────────────────────────────────────────────── */}
      {modal !== null && (
        <TaskModal
          defaultDate={modal.mode === "add" ? (modal.date ?? null) : null}
          editTask={modal.mode === "edit" ? (modal.task ?? null) : null}
          onClose={() => setModal(null)}
          onSaved={handleSaved}
        />
      )}
    </div>
  );
}
