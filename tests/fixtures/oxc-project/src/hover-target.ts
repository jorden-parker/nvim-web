interface Visitor {
  name: string
  visits: number
}

type Greeting = 'hello' | 'welcome back'

export const visitor: Visitor = { name: 'Ada', visits: 1 }
export const greeting: Greeting = 'hello'
export const visitCount = visitor.visits
export const pageTitle = document
