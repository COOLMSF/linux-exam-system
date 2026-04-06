import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import NotFound from "@/pages/NotFound";
import { Route, Switch } from "wouter";
import ErrorBoundary from "./components/ErrorBoundary";
import { ThemeProvider } from "./contexts/ThemeContext";
import Home from "./pages/Home";
import Dashboard from "./pages/Dashboard";
import Questions from "./pages/Questions";
import Students from "./pages/Students";
import Exams from "./pages/Exams";
import ScoringRules from "./pages/ScoringRules";
import Reports from "./pages/Reports";
import ExamOpsCenter from "./pages/ExamOpsCenter";
import StudentDashboard from "./pages/StudentDashboard";

function Router() {
  return (
    <Switch>
      <Route path="/" component={Home} />
      <Route path="/dashboard" component={Dashboard} />
      <Route path="/questions" component={Questions} />
      <Route path="/students" component={Students} />
      <Route path="/exams" component={Exams} />
      <Route path="/scoring-rules" component={ScoringRules} />
      <Route path="/reports" component={Reports} />
      <Route path="/exam-ops" component={ExamOpsCenter} />
      <Route path="/student" component={StudentDashboard} />
      <Route path="/404" component={NotFound} />
      <Route component={NotFound} />
    </Switch>
  );
}

function App() {
  return (
    <ErrorBoundary>
      <ThemeProvider defaultTheme="light">
        <TooltipProvider>
          <Toaster richColors position="top-right" />
          <Router />
        </TooltipProvider>
      </ThemeProvider>
    </ErrorBoundary>
  );
}

export default App;
