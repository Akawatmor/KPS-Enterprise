import { render, screen, waitFor, within, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import HomePage from "../app/page";
import * as apiModule from "../app/modules/api";

// ── Mock fetchAPI ─────────────────────────────────────────────────────────────
jest.mock("../app/modules/api", () => ({
  ...jest.requireActual("../app/modules/api"),
  fetchAPI: jest.fn(),
}));

const mockedFetchAPI = apiModule.fetchAPI as jest.MockedFunction<
  typeof apiModule.fetchAPI
>;

// ── Helpers ───────────────────────────────────────────────────────────────────
/**
 * Returns an ISO date-time string without timezone suffix so date-fns
 * treats it as local time — matching how the calendar groups tasks by day.
 */
function localISO(offsetDays = 0, hour = 10): string {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}T${String(hour).padStart(2, "0")}:00:00`;
}

/**
 * Renders HomePage and waits until the initial task fetch resolves.
 * Suppresses expected act() warnings from async state updates in useEffect.
 */
async function renderAndWait(): Promise<ReturnType<typeof render>> {
  let result!: ReturnType<typeof render>;
  await act(async () => {
    result = render(<HomePage />);
  });
  await waitFor(() =>
    expect(screen.queryByText("Syncing…")).not.toBeInTheDocument(),
  );
  return result;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────
const OPEN_TASK = {
  id: 1,
  title: "Buy groceries",
  priority: "normal" as const,
  due_at: localISO(0, 10),
  status: "open" as const,
};

const DONE_TASK = {
  id: 2,
  title: "Write report",
  priority: "high" as const,
  due_at: localISO(0, 14),
  status: "done" as const,
};

const TASKS = [OPEN_TASK, DONE_TASK];

// ── Shared helper: open today's day panel ─────────────────────────────────────
async function openTodayPanel(
  container: HTMLElement,
  user: ReturnType<typeof userEvent.setup>,
): Promise<void> {
  await waitFor(() =>
    expect(screen.getByText("2 total todos")).toBeInTheDocument(),
  );
  const todayCell = container.querySelector<HTMLElement>(".cal-day.today");
  await user.click(todayCell!);
  await waitFor(() =>
    expect(screen.getByText("Add todo for this day")).toBeInTheDocument(),
  );
}

// ── Test suites ───────────────────────────────────────────────────────────────
describe("HomePage", () => {
  beforeEach(() => {
    mockedFetchAPI.mockResolvedValue({ items: TASKS } as never);
    jest.spyOn(window, "confirm").mockReturnValue(true);
  });

  afterEach(() => jest.clearAllMocks());

  // ── Rendering ───────────────────────────────────────────────────────────────
  describe("Rendering", () => {
    it("renders the application header brand", async () => {
      await renderAndWait();
      expect(screen.getByText("TodoApp")).toBeInTheDocument();
    });

    it("renders all 7 weekday column headers", async () => {
      await renderAndWait();
      for (const day of ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]) {
        expect(screen.getByText(day)).toBeInTheDocument();
      }
    });

    it("shows the current month and year in the calendar nav", async () => {
      await renderAndWait();
      const label = new Intl.DateTimeFormat("en-US", {
        month: "long",
        year: "numeric",
      }).format(new Date());
      expect(screen.getByText(label)).toBeInTheDocument();
    });

    it("shows a syncing indicator before tasks load", () => {
      mockedFetchAPI.mockImplementationOnce(() => new Promise(() => {}));
      render(<HomePage />);
      expect(screen.getByText("Syncing…")).toBeInTheDocument();
    });

    it("shows total todo count after tasks load", async () => {
      await renderAndWait();
      expect(screen.getByText("2 total todos")).toBeInTheDocument();
    });
  });

  // ── Stats bar ────────────────────────────────────────────────────────────────
  describe("Stats bar", () => {
    it("shows correct open count (1)", async () => {
      await renderAndWait();
      const openItem = screen
        .getAllByText(/open/)
        .find((el) => el.closest(".stat-item"));
      expect(
        openItem?.closest(".stat-item")?.querySelector(".stat-value")
          ?.textContent,
      ).toBe("1");
    });

    it("shows correct done count (1)", async () => {
      await renderAndWait();
      const doneItem = screen
        .getAllByText(/done/)
        .find((el) => el.closest(".stat-item"));
      expect(
        doneItem?.closest(".stat-item")?.querySelector(".stat-value")
          ?.textContent,
      ).toBe("1");
    });
  });

  // ── Calendar grid ────────────────────────────────────────────────────────────
  describe("Calendar grid", () => {
    it("shows task pills for today's tasks after loading", async () => {
      const { container } = await renderAndWait();
      const todayCell = container.querySelector<HTMLElement>(".cal-day.today");
      expect(todayCell).not.toBeNull();
      expect(within(todayCell!).getByText("Buy groceries")).toBeInTheDocument();
    });

    it("navigates to the next month when clicking ChevronRight", async () => {
      const user = userEvent.setup();
      const { container } = await renderAndWait();

      const nextMonthDate = new Date();
      nextMonthDate.setMonth(nextMonthDate.getMonth() + 1);
      const expected = new Intl.DateTimeFormat("en-US", {
        month: "long",
        year: "numeric",
      }).format(nextMonthDate);

      const navBtns =
        container.querySelectorAll<HTMLButtonElement>(".cal-nav-btn");
      await user.click(navBtns[navBtns.length - 1]); // last = ChevronRight

      expect(screen.getByText(expected)).toBeInTheDocument();
    });

    it("navigates to the previous month when clicking ChevronLeft", async () => {
      const user = userEvent.setup();
      const { container } = await renderAndWait();

      const prevMonthDate = new Date();
      prevMonthDate.setMonth(prevMonthDate.getMonth() - 1);
      const expected = new Intl.DateTimeFormat("en-US", {
        month: "long",
        year: "numeric",
      }).format(prevMonthDate);

      const navBtns =
        container.querySelectorAll<HTMLButtonElement>(".cal-nav-btn");
      await user.click(navBtns[0]); // first = ChevronLeft

      expect(screen.getByText(expected)).toBeInTheDocument();
    });

    it("returns to the current month when clicking Today", async () => {
      const user = userEvent.setup();
      const { container } = await renderAndWait();

      // Navigate away first
      const navBtns =
        container.querySelectorAll<HTMLButtonElement>(".cal-nav-btn");
      await user.click(navBtns[navBtns.length - 1]); // go to next month

      await user.click(screen.getByText("Today"));

      const currentLabel = new Intl.DateTimeFormat("en-US", {
        month: "long",
        year: "numeric",
      }).format(new Date());
      expect(screen.getByText(currentLabel)).toBeInTheDocument();
    });
  });

  // ── Day panel ────────────────────────────────────────────────────────────────
  describe("Day panel", () => {
    it("opens when clicking a day cell", async () => {
      const user = userEvent.setup();
      const { container } = await renderAndWait();
      await openTodayPanel(container, user);
      expect(screen.getByText("Add todo for this day")).toBeInTheDocument();
    });

    it("displays both tasks for today in the panel", async () => {
      const user = userEvent.setup();
      const { container } = await renderAndWait();
      await openTodayPanel(container, user);

      expect(screen.getAllByText("Buy groceries").length).toBeGreaterThan(0);
      expect(screen.getAllByText("Write report").length).toBeGreaterThan(0);
    });

    it("closes when clicking the close button", async () => {
      const user = userEvent.setup();
      const { container } = await renderAndWait();
      await openTodayPanel(container, user);

      const closeBtn =
        container.querySelector<HTMLButtonElement>(".panel-close");
      await user.click(closeBtn!);

      await waitFor(() =>
        expect(
          screen.queryByText("Add todo for this day"),
        ).not.toBeInTheDocument(),
      );
    });
  });

  // ── Task interactions ────────────────────────────────────────────────────────
  describe("Task interactions", () => {
    it("sends PATCH request when toggling an open task to done", async () => {
      const user = userEvent.setup();
      mockedFetchAPI
        .mockResolvedValueOnce({ items: TASKS } as never)
        .mockResolvedValueOnce({ ...OPEN_TASK, status: "done" } as never);

      const { container } = await renderAndWait();
      await openTodayPanel(container, user);

      await user.click(screen.getByTitle("Mark done"));

      await waitFor(() =>
        expect(mockedFetchAPI).toHaveBeenCalledWith(
          "/tasks/1",
          expect.objectContaining({
            method: "PATCH",
            body: JSON.stringify({ status: "done" }),
          }),
        ),
      );
    });

    it("sends PATCH request when toggling a done task back to open", async () => {
      const user = userEvent.setup();
      mockedFetchAPI
        .mockResolvedValueOnce({ items: TASKS } as never)
        .mockResolvedValueOnce({ ...DONE_TASK, status: "open" } as never);

      const { container } = await renderAndWait();
      await openTodayPanel(container, user);

      await user.click(screen.getByTitle("Mark open"));

      await waitFor(() =>
        expect(mockedFetchAPI).toHaveBeenCalledWith(
          "/tasks/2",
          expect.objectContaining({
            method: "PATCH",
            body: JSON.stringify({ status: "open" }),
          }),
        ),
      );
    });

    it("sends DELETE request when deleting a task", async () => {
      const user = userEvent.setup();
      mockedFetchAPI
        .mockResolvedValueOnce({ items: TASKS } as never)
        .mockResolvedValueOnce(undefined as never);

      const { container } = await renderAndWait();
      await openTodayPanel(container, user);

      const deleteButtons = screen.getAllByTitle("Delete");
      await user.click(deleteButtons[0]);

      await waitFor(() =>
        expect(mockedFetchAPI).toHaveBeenCalledWith(
          expect.stringMatching(/\/tasks\/\d+/),
          expect.objectContaining({ method: "DELETE" }),
        ),
      );
    });

    it("does not delete when confirm dialog is cancelled", async () => {
      jest.spyOn(window, "confirm").mockReturnValueOnce(false);
      const user = userEvent.setup();

      const { container } = await renderAndWait();
      await openTodayPanel(container, user);

      const callCountAfterLoad = mockedFetchAPI.mock.calls.length;
      const deleteButtons = screen.getAllByTitle("Delete");
      await user.click(deleteButtons[0]);

      // No additional calls after the initial load
      expect(mockedFetchAPI).toHaveBeenCalledTimes(callCountAfterLoad);
    });
  });

  // ── Task modal ───────────────────────────────────────────────────────────────
  describe("Task modal", () => {
    it("opens the Add Todo modal when clicking New Todo", async () => {
      const user = userEvent.setup();
      await renderAndWait();

      await user.click(screen.getByRole("button", { name: /new todo/i }));

      expect(
        screen.getByRole("button", { name: "Add Todo" }),
      ).toBeInTheDocument();
    });

    it("closes the modal when clicking Cancel", async () => {
      const user = userEvent.setup();
      await renderAndWait();

      await user.click(screen.getByRole("button", { name: /new todo/i }));
      await user.click(screen.getByRole("button", { name: "Cancel" }));

      await waitFor(() =>
        expect(
          screen.queryByRole("button", { name: "Add Todo" }),
        ).not.toBeInTheDocument(),
      );
    });

    it("submits a new task via POST /tasks", async () => {
      const user = userEvent.setup();
      mockedFetchAPI
        .mockResolvedValueOnce({ items: TASKS } as never) // initial load
        .mockResolvedValueOnce({ ...OPEN_TASK, id: 3, title: "New task" } as never) // POST
        .mockResolvedValueOnce({ items: TASKS } as never); // reload after save

      await renderAndWait();

      await user.click(screen.getByRole("button", { name: /new todo/i }));

      const titleInput = screen.getByPlaceholderText("What needs to be done?");
      await user.type(titleInput, "New task");

      await user.click(screen.getByRole("button", { name: "Add Todo" }));

      await waitFor(() =>
        expect(mockedFetchAPI).toHaveBeenCalledWith(
          "/tasks",
          expect.objectContaining({ method: "POST" }),
        ),
      );

      // Wait for the modal to close and the reload to finish
      await waitFor(() =>
        expect(
          screen.queryByRole("button", { name: "Add Todo" }),
        ).not.toBeInTheDocument(),
      );
    });

    it("shows a validation error when submitting with an empty title", async () => {
      const user = userEvent.setup();
      await renderAndWait();

      await user.click(screen.getByRole("button", { name: /new todo/i }));
      await user.click(screen.getByRole("button", { name: "Add Todo" }));

      expect(screen.getByText("Title is required")).toBeInTheDocument();
    });
  });
});
